module Exportable
    extend ActiveSupport::Concern
  
    included do
      class_attribute :export_fields
    end
  
    class_methods do
      def setup_exportable(fields: [], include: [])
        self.export_fields = {
          fields: fields,
          include: include
        }
      end
  
      def to_xlsx
        package = Axlsx::Package.new
        wb = package.workbook
  
        wb.add_worksheet(name: model_name.human.pluralize) do |sheet|
          add_headers(sheet)
          add_rows(sheet)
        end
  
        package.to_stream.read
      end
  
      private
     
      def add_headers(sheet)
        headers = []
        
        headers += export_fields[:fields].map { |f| human_attribute_name(f) }
  
        export_fields[:include].each do |assoc|
          next unless reflections.key?(assoc.to_s)
          
          klass = reflections[assoc.to_s].klass
          next unless klass.respond_to?(:export_fields)
  
          klass.export_fields[:fields].each do |f|
            headers << "#{klass.model_name.human} #{klass.human_attribute_name(f)}"
          end
        end
  
        sheet.add_row(headers, style: header_style(sheet))
      end
  
      def add_rows(sheet)
        includes(export_fields[:include]).find_each do |record|
          row = []
          
          row += export_fields[:fields].map { |f| record.send(f) }
  
          export_fields[:include].each do |assoc|
            associated = record.send(assoc)
            next unless associated.class.respond_to?(:export_fields)
  
            row += associated.class.export_fields[:fields].map { |f| associated&.send(f) }
          end
  
          sheet.add_row(row)
        end
      end
  
      def header_style(sheet)
        sheet.styles.add_style(
          b: true,
          bg_color: 'DDDDDD',
          alignment: { horizontal: :center }
        )
      end
    end
  end