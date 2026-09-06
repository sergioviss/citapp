# frozen_string_literal: true

require "test_helper"

class OperationsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:receptionist)
    @client = create_client!
    @service = create_service!(price: 100)
    @employee = create_employee!(services: [ @service ])
  end

  test "API runs booking sale receipt cancellation and refund with real balances" do
    post api_v1_appointments_path, params: { appointment: {
      client_id: @client.id, employee_id: @employee.id, service_ids: [ @service.id ], starts_at: "2026-06-01T10:00"
    } }, as: :json
    assert_response :created
    appointment_id = response.parsed_body.fetch("id")
    post from_appointment_api_v1_sales_path, params: { appointment_id: appointment_id,
      sale: { payments: [ { method: "cash", amount: "150.00" } ] } }, as: :json
    assert_response :created
    sale_id = response.parsed_body.fetch("id")
    assert Sale.find(sale_id).posted?
    payment_id = Sale.find(sale_id).payments.sole.id
    post api_v1_sale_payments_path(sale_id), params: { payment: {
      amount: "100.00", method: "cash", tendered_amount: "150.00", idempotency_key: SecureRandom.uuid
    } }, as: :json
    assert_response :unprocessable_entity
    assert_equal 1, Payment.where(sale_id: sale_id).count
    assert_equal 0, SaleBalance.find(sale_id).balance
    post cancel_api_v1_sale_path(sale_id), as: :json
    assert_response :success
    assert_equal(-100, SaleBalance.find(sale_id).balance)
    post refund_api_v1_sale_payments_path(sale_id), params: { payment: {
      original_payment_id: payment_id, amount: 100, method: "cash", reason: "Cancelación", idempotency_key: SecureRandom.uuid
    } }, as: :json
    assert_response :created
    assert_equal 0, SaleBalance.find(sale_id).balance
  end

  test "HTML pages render operational forms and saved records" do
    get operations_catalogs_path
    assert_response :success
    assert_select "h1", "Catálogos y horarios"
    get operations_employee_path(@employee)
    assert_response :success
    assert_select "form.ops-employee-form[action=?]", operations_employee_path(@employee)
    assert_select "form[action=?]", day_working_hours_operations_employee_path(@employee), count: 0
    assert_select "form.ops-employee-form input[type=submit][value=Guardar]", count: 0
    assert_select "a.btn-primary", text: "Editar"
    get operations_root_path
    assert_response :success
    assert_select "form[action=?]", operations_appointments_path
    get operations_sales_path
    assert_response :success
    assert_select "th", "Folio"
    assert_select "th", "Servicios"
    assert_select "th", "Total"
    assert_select "th", "Empleado"
    assert_select "th", "Acciones"
    assert_select "th", text: "Estado", count: 0
    post operations_sales_path, params: { sale: { client_id: @client.id, payments: [ { method: "cash", amount: 100 } ],
      items: { "0" => { service_id: @service.id, quantity: 1, unit_price: "" } } } }
    assert_response :see_other
    follow_redirect!
    assert_response :success
    assert_select "h1", /Venta #/
    assert_select "form[action=?]", operations_sale_payments_path(Sale.last), count: 0
  end

  test "weekly hours form preserves 24:00 through HTTP and PostgreSQL" do
    put working_hours_api_v1_employee_path(@employee), params: { slots: {
      "0" => { weekday: "1", starts_at: "22:00", ends_at: "24:00" },
      "1" => { weekday: "", starts_at: "", ends_at: "" }
    } }, as: :json
    assert_response :success
    assert_equal 86400, @employee.employee_working_hours.reload.first.ends_at_seconds
    post api_v1_appointments_path, params: { appointment: {
      client_id: @client.id, employee_id: @employee.id, service_ids: [ @service.id ], starts_at: "2026-06-01T23:30"
    } }, as: :json
    assert_response :created
  end

  test "API returns useful errors and rolls back invalid booking" do
    assert_no_difference "Appointment.count" do
      post api_v1_appointments_path, params: { appointment: {
        client_id: @client.id, employee_id: @employee.id, service_ids: [], starts_at: "2026-06-01T10:00"
      } }, as: :json
    end
    assert_response :unprocessable_entity
    assert_match(/servicio/, response.parsed_body.fetch("error"))
  end

  test "employees cannot create sales or view another employee's agenda" do
    own = create_employee!(user: users(:employee), services: [ @service ])
    first = book_appointment!(employee: own, client: @client, services: [ @service ], starts_at: "2026-06-01 10:00")
    book_appointment!(employee: @employee, client: @client, services: [ @service ], starts_at: "2026-06-01 11:00")
    sign_in users(:employee)
    get api_v1_appointments_path, params: { date: "2026-06-01" }, as: :json
    assert_response :success
    assert_equal [ first.id ], response.parsed_body.map { |row| row.fetch("id") }
    post api_v1_sales_path, params: { sale: { client_id: @client.id, items: [] } }, as: :json
    assert_response :forbidden
  end

  test "unauthenticated JSON operations require login" do
    sign_out users(:receptionist)
    get api_v1_sales_path, as: :json
    assert_response :unauthorized
  end

  test "receptionist cannot change business settings" do
    patch api_v1_settings_path, params: { business_setting: { currency: "USD" } }, as: :json
    assert_response :forbidden
  end

  test "HTML booking returns to the date of the saved appointment" do
    post operations_appointments_path, params: { appointment: {
      client_id: @client.id, employee_id: @employee.id, service_ids: [ @service.id ], starts_at: "2026-06-01T10:00"
    } }
    assert_redirected_to operations_root_path(date: "2026-06-01")
    follow_redirect!
    assert_select "h2", /10:00.*Cliente/
  end

  test "operational forms retain CSRF protection for session requests" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get operations_root_path
    token = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    assert_no_difference "Client.count" do
      post api_v1_clients_path, params: { client: { name: "Invalid CSRF" } }, as: :json
    end
    assert_response :unprocessable_entity
    post api_v1_clients_path, params: { client: { name: "Valid CSRF" } },
      headers: { "X-CSRF-Token" => token }, as: :json
    assert_response :created
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "sales index lists services and employee and hides destroy from receptionists" do
    appointment = book_appointment!(employee: @employee, client: @client, services: [ @service ], starts_at: "2026-06-01 10:00")
    sale = Sales::SaveDraft.call(actor: users(:admin), client_id: @client.id, appointment_id: appointment.id,
      items: [ { service_id: @service.id, appointment_service_id: appointment.appointment_services.first.id } ])

    get datatable_operations_sales_path, params: { length: 10 }, as: :json
    assert_response :success
    row = response.parsed_body["data"].find { |entry| entry.first.include?("##{sale.id}") }
    assert_equal 5, row.size
    assert_includes row[1], @service.name
    assert_includes row[3], @employee.name
    assert_not_includes row.last, "data-sale-delete"

    delete operations_sale_path(sale), as: :json
    assert_response :forbidden
    assert Sale.exists?(sale.id)

    sign_in users(:admin)
    get datatable_operations_sales_path, params: { length: 10 }, as: :json
    admin_row = response.parsed_body["data"].find { |entry| entry.first.include?("##{sale.id}") }
    assert_includes admin_row.last, "data-sale-delete"

    delete operations_sale_path(sale), as: :json
    assert_response :success
    assert_not Sale.exists?(sale.id)
  end

  test "cash payment validates received cash and overcharge" do
    sale = Sales::SaveDraft.call(actor: users(:admin), client_id: @client.id, items: [ { service_id: @service.id } ])
    post api_v1_sale_payments_path(sale), params: { payment: {
      amount: 100, method: "cash", tendered_amount: 50, idempotency_key: SecureRandom.uuid
    } }, as: :json
    assert_response :unprocessable_entity
    assert_equal 0, sale.payments.count
    post api_v1_sale_payments_path(sale), params: { payment: {
      amount: 101, method: "card", idempotency_key: SecureRandom.uuid
    } }, as: :json
    assert_response :unprocessable_entity
  end
end
