module ActiveRecord
  module Extensions
    module BinaryColumnTable
      CLASS_NAME = "BinaryColumn"
      def self.included(base)
        base.class_eval do
          def self.has_binary_columns(*column_names)
            # 1. create a has_one relationship
            # 2. create accessor methods to wrap has_one usage
            column_names.each do |colname|
              has_one "#{colname}_binary_column",
                :class_name => BinaryColumnTable::CLASS_NAME,
                :as => "original_table",
                :conditions => {:name => "#{colname}"},
                :dependent => :delete
              self.class_eval <<-METHOD
                def #{colname}
                  self.#{colname}_binary_column.try(:content)
                end
                def #{colname}=(val)
                  if not val.blank?
                    self.#{colname}_binary_column ||= #{BinaryColumnTable::CLASS_NAME}.new(:original_table => self, :name => "#{colname}")
                    self.#{colname}_binary_column.content = val.respond_to?(:read) ? val.read : val
                    if self.#{colname}_binary_column.respond_to?(:content_type)
                      # optional content_type extraction
                      begin
                        if val.respond_to?(:path)
                          filepath = val.path
                        else
                          Tempfile.open("binary_column_table") {|f| filepath = f.path; f.write self.#{colname}_binary_column.content }
                        end
                        self.#{colname}_binary_column.content_type = IO.popen("file --mime \#{filepath.inspect}") {|io| io.gets.sub(/^.+?: /, '').strip }
                      rescue Exception, IOError
                      end
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
ActiveRecord::Base.send(:include, ActiveRecord::Extensions::BinaryColumnTable)