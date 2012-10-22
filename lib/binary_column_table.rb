module ActiveRecord
  module Extensions
    module BinaryColumnTable
      CLASS_NAME = "BinaryColumn"
      def self.included(base)
        base.instance_eval do
          def has_binary_columns(*column_names)
            # 1. create a has_one relationship
            # 2. create accessor methods to wrap has_one usage

            # Do not run this unless table exists (fix for "rake db:*" tasks)
            return unless ActiveRecord::Base.connection.table_exists? 'binary_columns'
            column_names.each do |colname|
              has_one "#{colname}_binary_column",
                :class_name => BinaryColumnTable::CLASS_NAME,
                :as => "original_table",
                :conditions => {:name => "#{colname}"},
                :dependent => :delete
              has_one "#{colname}_attributes",
                :class_name => BinaryColumnTable::CLASS_NAME,
                :as => "original_table",
                :conditions => {:name => "#{colname}"},
                :readonly => true,
                :select => (ActiveRecord::Extensions::BinaryColumnTable::CLASS_NAME.constantize.column_names - ["content"]).join(',')
              self.class_eval <<-METHOD
                def #{colname}
                  self.#{colname}_binary_column.respond_to?(:content) ? self.#{colname}_binary_column.content : nil
                end
                def #{colname}=(val)
                  if not val.blank?
                    self.#{colname}_binary_column ||= #{BinaryColumnTable::CLASS_NAME}.new(:original_table => self, :name => "#{colname}")
                    self.#{colname}_binary_column.original_table_id = nil # ensure this object is saved, even when parent is not dirty
                    self.#{colname}_binary_column.content = val.respond_to?(:read) ? val.read : val
                    self.#{colname}_binary_column.original_filename = File.basename(val.original_filename) if val.respond_to?(:original_filename) && self.#{colname}_binary_column.respond_to?(:original_filename=)
                    self.#{colname}_binary_column.content_type = val.content_type if val.respond_to?(:content_type) && self.#{colname}_binary_column.respond_to?(:content_type=)
                    val.respond_to?(:original_filename) && val.respond_to?(:content_type) || begin
                      # last-ditch attempt to obtain 'content_type'
                      if val.respond_to?(:path) && val.path.present?
                        filepath = val.path
                      else
                        Tempfile.open("binary_column_table") {|f| filepath = f.path; f.write(self.#{colname}_binary_column.content); }
                      end
                      self.#{colname}_binary_column.content_type = IO.popen("file --mime \#{filepath.inspect}") {|io| io.gets.split(/:\s*/).last.strip }
                    rescue Exception, IOError
                      # but don't die because this fail
                    end
                  end
                end
              METHOD
            end
          end
        end
      end
    end
  end
end
