module DatatableResponder
    extend ActiveSupport::Concern
  
    def datatable_response
      model = controller_name.classify.constantize
      datatable = model.datatable(params)
  
      render json: {
        draw: params[:draw].to_i,
        recordsTotal: datatable[:recordsTotal],
        recordsFiltered: datatable[:recordsFiltered],
        data: datatable[:data]
      }
      
    end
  end