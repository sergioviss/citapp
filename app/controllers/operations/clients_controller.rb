# frozen_string_literal: true

module Operations
  class ClientsController < BaseController
    include OperationsCatalog

    def lookup
      allowed! :read, Client
      query = params[:q].to_s.strip.first(100)
      pattern = "%#{Client.sanitize_sql_like(query)}%"
      digits = query.gsub(/\D/, "")
      scope = Client.where("name ILIKE :pattern OR phone ILIKE :pattern", pattern: pattern)
      if digits.present?
        scope = scope.or(Client.where("regexp_replace(phone, '[^0-9]', '', 'g') LIKE ?", "%#{digits}%"))
      end
      render json: scope.order(:name, :id).limit(20).as_json(only: %i[id name phone email])
    end
    def create
      allowed! :create, Client
      saved(Client.create!(attributes), location: operations_clients_path, status: :created)
    end

    def update
      record = Client.find(params[:id])
      allowed! :update, record
      record.update!(attributes)
      saved(record, location: operations_clients_path)
    end

    def destroy
      record = Client.find(params[:id])
      allowed! :destroy, record
      record.with_lock do
        if record.appointments.exists? || record.sales.exists?
          raise Domain::Conflict, "El cliente tiene citas o ventas registradas. No se puede eliminar."
        end
        record.destroy!
      end
      saved({ id: record.id }, location: operations_clients_path)
    end

    private

    def attributes
      params.require(:client).permit(:name, :phone, :email)
    end
  end
end
