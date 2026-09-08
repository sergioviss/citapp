# frozen_string_literal: true

require "test_helper"

class OperationsUiTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:receptionist)
    @client = create_client!(name: "Ana López")
    @client.update!(phone: "+52 (662) 123-4567")
    @service = create_service!(name: "Corte especial", price: "120.50")
    @employee = create_employee!(services: [ @service ])
  end

  test "catalog tables use the theme and return escaped searchable paginated rows" do
    malicious = create_client!(name: "<img src=x onerror=alert(1)>")
    [ operations_clients_path, operations_services_path, operations_employees_path, operations_sales_path, new_operations_sale_path, operations_settings_path ].each do |path|
      get path
      assert_response :success
      assert_select ".sidebar a[href=?]", operations_root_path
      assert_select 'link[href="/operations-ui/operations.css"]'
    end
    get operations_root_path
    assert_select ".sidebar li.nav-item a" do |links|
      assert_equal %w[Agenda Ventas Usuarios Empleados Servicios Clientes Configuración], links.map { |link| link.text.strip }
    end
    assert_select ".sidebar li.nav-item svg", count: 7
    get datatable_operations_clients_path, params: { draw: "7", start: 0, length: 10, search: { value: "<img" }, order: { "0" => { column: "0", dir: "desc" } } }, as: :json
    assert_response :success
    data = response.parsed_body
    assert_equal 7, data["draw"]
    assert_equal 1, data["recordsFiltered"]
    assert_equal ERB::Util.html_escape(malicious.name), data["data"][0][0]
    assert_equal 1, data["data"].length
  end

  test "index actions are accessible icon buttons" do
    get datatable_operations_clients_path, params: { length: 10 }, as: :json
    assert_response :success
    client_action = response.parsed_body.fetch("data").first.last
    assert_includes client_action, "ops-action-icon"
    assert_includes client_action, "Editar #{@client.name}"
    assert_not_includes client_action, ">Editar<"
    assert_includes client_action, "ops-table-actions"
    assert_not_includes client_action, "data-catalog-delete"

    get datatable_operations_services_path, params: { length: 10 }, as: :json
    service_action = response.parsed_body.fetch("data").first.last
    assert_includes service_action, "Editar #{@service.name}"
    assert_not_includes service_action, "data-catalog-delete"

    get datatable_operations_employees_path, params: { length: 10 }, as: :json
    employee_action = response.parsed_body.fetch("data").first.last
    assert_includes employee_action, "ops-action-icon"
    assert_includes employee_action, "ops-table-actions"
    assert_includes employee_action, "ops-action-icon--danger"

    sale = Sales::SaveDraft.call(actor: users(:receptionist), client_id: @client.id, items: [ { service_id: @service.id } ])
    get datatable_operations_sales_path, params: { length: 10 }, as: :json
    assert_response :success
    sale_action = response.parsed_body.fetch("data").find { |row| row.first.include?("##{sale.id}") }.last
    assert_includes sale_action, "ops-action-icon"
    assert_includes sale_action, "ops-table-actions"
    assert_includes sale_action, "Ver venta ##{sale.id}"
    assert_not_includes sale_action, ">Ver venta<"
  end

  test "POS searches clients by name and phone regardless of formatting and hides inactive services" do
    [ "ana", "6621234567", "662 123-4567" ].each do |query|
      get lookup_operations_clients_path, params: { q: query }, as: :json
      assert_response :success
      assert_equal [ @client.id ], response.parsed_body.map { |client| client["id"] }
    end
    create_service!(name: "Corte inactivo", active: false)
    get lookup_operations_services_path, params: { q: "corte" }, as: :json
    assert_equal [ @service.id ], response.parsed_body.map { |service| service["id"] }
  end

  test "POS fixes catalog prices and records the employee who attended each service" do
    get new_operations_sale_path
    assert_response :success
    assert_select "th", "Atendió"
    assert_select "input[aria-label^='Precio de']", count: 0

    post operations_sales_path, params: { sale: {
      client_id: @client.id,
      checkout_key: SecureRandom.uuid,
      payments: [ { method: "cash", amount: "120.50" } ],
      items: [ { service_id: @service.id, employee_id: @employee.id, unit_price: "1.00" } ]
    } }, as: :json

    assert_response :created
    item = Sale.find(response.parsed_body.fetch("id")).sale_items.first
    assert_equal @employee, item.employee
    assert_equal BigDecimal("120.50"), item.unit_price
  end

  test "POS creates a client and sale together and calculates totals on the server" do
    assert_difference [ "Client.count", "Sale.count" ], 1 do
      post operations_sales_path, params: { sale: {
        new_client: { name: "Cliente del mostrador", phone: "6625551234" },
        discount_percent: 10, payments: [ { method: "cash", amount: "300.00" } ],
        items: [ { service_id: @service.id, quantity: 2, unit_price: "120.50", tax_rate: "0.16" } ]
      } }, as: :json
      assert_response :created
    end
    sale = Sale.find(response.parsed_body["id"])
    assert_equal "Cliente del mostrador", sale.client.name
    assert_equal BigDecimal("216.90"), sale.total
    assert_equal BigDecimal("0.00"), sale.tax_total
    assert_equal operations_sale_path(sale), response.headers["Location"]
  end

  test "failed POS sale does not leave an orphan client or partial sale" do
    assert_no_difference [ "Client.count", "Sale.count", "SaleItem.count" ] do
      post operations_sales_path, params: { sale: { new_client: { name: "No debe persistir" },
        items: [ { service_id: @service.id, discount_amount: "999.00" } ] } }, as: :json
      assert_response :unprocessable_entity
    end
    assert_no_difference "Client.count" do
      post operations_sales_path, params: { sale: { new_client: { name: "Ambiguo" }, client_id: @client.id,
        items: [ { service_id: @service.id } ] } }, as: :json
      assert_response :unprocessable_entity
    end
  end

  test "calendar includes local times and excludes other employees for employee role" do
    own = create_employee!(user: users(:employee), services: [ @service ])
    appointment = book_appointment!(employee: own, client: @client, services: [ @service ], starts_at: "2026-06-01 10:00")
    sign_in users(:employee)
    get operations_root_path, params: { date: "2026-06-01" }
    assert_response :success
    columns = JSON.parse(response.parsed_body.at_css("#calendar-data").text)
    assert_equal [ own.id ], columns.map { |column| column["id"] }
    assert_equal "2026-06-01T10:00:00", columns.first["events"].first["start"]
    assert_equal appointment.id, columns.first["events"].first["id"]
    assert_select "[data-new-booking]", count: 0
    assert_select 'script[src="/assets/js/fullcalendar.min.js"]'
    get lookup_operations_clients_path, params: { q: "ana" }, as: :json
    assert_response :forbidden
    get lookup_operations_services_path, as: :json
    assert_response :forbidden
  end

  test "calendar client limits the visible day and uses its shared scroll container" do
    javascript = Rails.root.join("public/operations-ui/operations.js").read
    stylesheet = Rails.root.join("public/operations-ui/operations.css").read

    assert_includes javascript, "slotMinTime: '08:00:00'"
    assert_includes javascript, "slotMaxTime: '20:00:00'"
    assert_includes javascript, "height: 'auto'"
    assert_not_includes javascript, "const scrollers ="
    assert_includes stylesheet, ".ops-calendar-scroll { max-height:660px; overflow:auto;"
    assert_includes stylesheet, ".ops-calendar-column .fc-scroller { overflow:visible !important; }"
  end

  test "sales table lists totals and published sales cannot be edited in POS" do
    sale = Sales::SaveDraft.call(actor: users(:receptionist), client_id: @client.id, items: [ { service_id: @service.id } ])
    get datatable_operations_sales_path, params: { length: 10, search: { value: "Ana" } }, as: :json
    assert_response :success
    assert_equal 1, response.parsed_body["recordsFiltered"]
    row = response.parsed_body["data"].first
    assert_match "120.50", row[2]
    assert_includes row.last, "ops-action-icon"
    Sales::Publish.call(actor: users(:receptionist), sale: sale)
    get edit_operations_sale_path(sale), as: :json
    assert_response :unprocessable_entity
  end

  test "only admins can delete unused clients and services" do
    unused_client = create_client!(name: "Cliente sin historial")
    unused_service = create_service!(name: "Servicio sin historial")
    delete operations_client_path(unused_client), as: :json
    assert_response :forbidden
    delete operations_service_path(unused_service), as: :json
    assert_response :forbidden

    sign_in users(:admin)
    get datatable_operations_clients_path, params: { length: 10, search: { value: unused_client.name } }, as: :json
    assert_includes response.parsed_body.fetch("data").first.last, "data-catalog-delete"
    get datatable_operations_services_path, params: { length: 10, search: { value: unused_service.name } }, as: :json
    assert_includes response.parsed_body.fetch("data").first.last, "data-catalog-delete"

    assert_difference "Client.count", -1 do
      delete operations_client_path(unused_client), as: :json
      assert_response :success
    end
    assert_difference "Service.count", -1 do
      delete operations_service_path(unused_service), as: :json
      assert_response :success
    end
    Sales::SaveDraft.call(actor: users(:admin), client_id: @client.id, items: [ { service_id: @service.id } ])
    delete operations_client_path(@client), as: :json
    assert_response :conflict
    delete operations_service_path(@service), as: :json
    assert_response :conflict
  end
end
