# frozen_string_literal: true

module Operations
  class SalesController < BaseController
    def index
      allowed! :read, Sale
      @sales = Sale.includes(:client, :sale_balance).order(created_at: :desc).limit(100)
      respond_to do |format|
        format.html
        format.json { render json: @sales.as_json(include: :sale_balance) }
      end
    end

    def datatable
      allowed! :read, Sale
      table_page(Sale.left_joins(:client, appointment: :employee).preload(:sale_items, appointment: :employee),
        columns: %w[sales.id sales.id sales.total employees.name],
        search_columns: [
          "CAST(sales.id AS TEXT)",
          "clients.name",
          "employees.name",
          "(SELECT COALESCE(string_agg(description, ' '), '') FROM sale_items WHERE sale_items.sale_id = sales.id)"
        ]) { |record| helpers.operations_sale_row(record) }
    end

    def new
      allowed! :create, Sale
      @employees = Employee.active.order(:name)
      @sale = Sale.new(currency: BusinessSetting.current!.currency)
      if params[:appointment_id].present?
        appointment = Appointment.find(params[:appointment_id])
        return redirect_to operations_sale_path(appointment.sale) if appointment.sale
        @sale.assign_attributes(appointment: appointment, client: appointment.client, currency: appointment.currency)
        appointment.appointment_services.each do |line|
          @sale.sale_items.build(service_id: line.service_id, appointment_service_id: line.id,
            employee_id: appointment.employee_id, description: line.service_name, quantity: 1, unit_price: line.quoted_price, discount_amount: 0, tax_rate: 0)
        end
      end
    end

    def edit
      @sale = Sale.find(params[:id])
      allowed! :update, @sale
      raise Domain::ValidationError, "Solo se puede editar una venta en borrador" unless @sale.draft?

      @employees = Employee.active.order(:name)
      render :new
    end

    def show
      @sale = Sale.find(params[:id])
      allowed! :read, @sale
      @items = @sale.sale_items.includes(:service, :employee)
      @payments = @sale.payments.order(:occurred_at)
      @attempts = @sale.payment_attempts.order(:created_at)
      @services = Service.active.order(:name)
      respond_to do |format|
        format.html
        format.json { render json: @sale.as_json(include: [ :sale_items, :payments, :sale_balance, :payment_attempts ]) }
      end
    end

    def create
      record = Sales::Checkout.call(actor: current_user, **checkout_attributes)
      saved(record, location: operations_sale_path(record), status: :created)
    end

    def from_appointment
      appointment = Appointment.find(params[:appointment_id])
      allowed! :create, Sale
      return saved(appointment.sale, location: operations_sale_path(appointment.sale)) if appointment.sale
      if params[:sale].blank?
        return saved({ appointment_id: appointment.id }, location: new_operations_sale_path(appointment_id: appointment.id))
      end
      data = checkout_attributes.merge(client_id: appointment.client_id, appointment_id: appointment.id,
        items: appointment.appointment_services.map { |line| { service_id: line.service_id, appointment_service_id: line.id, employee_id: appointment.employee_id } })
      record = Sales::Checkout.call(actor: current_user, **data)
      saved(record, location: operations_sale_path(record), status: :created)
    end

    def update
      record = Sales::Checkout.call(actor: current_user, sale: Sale.find(params[:id]), **checkout_attributes)
      saved(record, location: operations_sale_path(record))
    end

    def publish
      allowed! :update, Sale.find(params[:id])
      raise Domain::ValidationError, "Guarda la venta con sus pagos desde el formulario de venta"
    end

    def cancel
      record = Sales::Cancel.call(actor: current_user, sale: Sale.find(params[:id]))
      saved(record, location: operations_sale_path(record))
    end

    def destroy
      record = Sale.find(params[:id])
      Sales::Destroy.call(actor: current_user, sale: record)
      saved({ id: record.id }, location: operations_sales_path)
    end

    private

    def checkout_attributes
      data = params.require(:sale).permit(:client_id, :appointment_id, :notes, :currency, :discount_percent, :checkout_key, :exchange_rate,
        payments: [ :method, :amount ],
        new_client: [ :name, :phone, :email ],
        items: [ :service_id, :appointment_service_id, :employee_id, :description, :quantity, :discount_amount ]).to_h.symbolize_keys
      items = data.fetch(:items, [])
      items = items.values if items.respond_to?(:values)
      data[:items] = items.map { |item| item.symbolize_keys }.reject { |item| item[:service_id].blank? }
      data[:items].each { |item| item.delete_if { |key, value| value.blank? && key != :service_id } }
      payments = data.fetch(:payments, [])
      data[:payments] = payments.respond_to?(:values) ? payments.values : payments
      data[:new_client] = data[:new_client].symbolize_keys if data[:new_client]
      data
    end
  end
end
