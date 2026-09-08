# frozen_string_literal: true

module Operations
  class ServicesController < BaseController
    include OperationsCatalog

    def lookup
      allowed! :read, Service
      pattern = "%#{Service.sanitize_sql_like(params[:q].to_s.strip.first(100))}%"
      render json: Service.active.where("name ILIKE ?", pattern).order(:name, :id).limit(20)
        .as_json(only: %i[id name duration_minutes price])
    end
    def create
      allowed! :create, Service
      record = Service.transaction { Service.create!(attributes) }
      saved(record, location: operations_services_path, status: :created)
    end

    def update
      record = Service.find(params[:id])
      allowed! :update, record
      Service.transaction { record.update!(attributes) }
      saved(record, location: operations_services_path)
    end

    def destroy
      record = Service.find(params[:id])
      allowed! :destroy, record
      record.with_lock do
        if record.employee_services.exists? || record.appointment_services.exists? || record.sale_items.exists?
          raise Domain::Conflict, "El servicio está asignado o tiene historial. No se puede eliminar."
        end
        record.destroy!
      end
      saved({ id: record.id }, location: operations_services_path)
    end

    private

    def attributes
      data = params.require(:service).permit(:name, :duration_minutes, :price, :active, :category_id)
      category_name = params.require(:service).permit(:new_category_name)[:new_category_name].to_s.strip
      if category_name.present?
        category = ServiceCategory.where("lower(name) = ?", category_name.downcase).first || ServiceCategory.create!(name: category_name)
        data[:category_id] = category.id
      end
      data
    end
  end
end
