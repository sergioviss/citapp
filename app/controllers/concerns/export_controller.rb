module ExportController
    extend ActiveSupport::Concern
  
    included do
      def export
        model = controller_name.classify.constantize
        send_data model.to_xlsx,
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  disposition: 'attachment',
                  filename: "#{model.model_name.plural}-#{Date.today}.xlsx"
      end
    end
  end