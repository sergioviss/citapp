# frozen_string_literal: true

require "test_helper"

class EmployeeEditorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:receptionist)
    @service = create_service!
    @employee = create_employee!(services: [ @service ])
  end

  test "employee show is read-only and links to edit" do
    get operations_employee_path(@employee)
    assert_response :success
    assert_select "h1", @employee.name
    assert_select "a.btn-primary[href=?]", edit_operations_employee_path(@employee), text: "Editar"
    assert_select "form.ops-employee-form input[type=submit][value=Guardar]", count: 0
    assert_select ".ops-hours-table--readonly"
    assert_select ".ops-day-actions", count: 0
  end

  test "employee edit shows seven fixed days and categories at the bottom" do
    get edit_operations_employee_path(@employee)
    assert_response :success
    assert_select "form.ops-employee-form[action=?]", operations_employee_path(@employee)
    assert_select "[data-weekday]", count: 7
    assert_select "h2", "Horario semanal"
    assert_select "h2", "Ausencias"
    assert_select ".ops-category-accordion summary", /General/
    assert_select "section:last-of-type", text: /Servicios asignados/
    assert_select "form.ops-employee-form input[type=submit][value=Guardar]", count: 1
    assert_select "form.ops-employee-form input[type=submit]", count: 1
    assert_select ".ops-hours-head [role=columnheader]", text: "Hora de entrada"
    assert_select ".ops-hours-head [role=columnheader]", text: "Hora de salida"
    assert_select ".ops-hours-table input[type=time]", count: 14
    assert_select ".ops-time-field", count: 14
    assert_select "button", text: "＋ Agregar tramo", count: 0
    assert_select "form[action=?]", day_working_hours_operations_employee_path(@employee), count: 0
    get datatable_operations_employees_path, params: { length: 10 }, as: :json
    actions = response.parsed_body["data"].first.last
    assert_includes actions, edit_operations_employee_path(@employee)
    assert_includes actions, "data-employee-delete"
    assert_not_includes actions, "horario y servicios"
  end

  test "daily hours edit and disable preserve the other days" do
    preserved = @employee.employee_working_hours.where.not(weekday: 1).order(:weekday).pluck(:weekday, :starts_at, :ends_at)
    patch day_working_hours_operations_employee_path(@employee), params: {
      weekday: 1, enabled: true, slots: [ { starts_at: "10:00", ends_at: "13:00" }, { starts_at: "14:00", ends_at: "20:00" } ]
    }, as: :json
    assert_response :success
    assert_equal [ [ "10:00:00", "13:00:00" ] ], @employee.employee_working_hours.where(weekday: 1).pluck(:starts_at, :ends_at)
    assert_equal preserved, @employee.employee_working_hours.where.not(weekday: 1).order(:weekday).pluck(:weekday, :starts_at, :ends_at)
    patch day_working_hours_operations_employee_path(@employee), params: { weekday: 1, enabled: false }, as: :json
    assert_response :success
    assert_empty @employee.employee_working_hours.where(weekday: 1)
    assert_equal preserved, @employee.employee_working_hours.where.not(weekday: 1).order(:weekday).pluck(:weekday, :starts_at, :ends_at)
  end

  test "cannot disable a day with booked appointments or delete its employee" do
    book_appointment!(employee: @employee, client: create_client!, services: [ @service ], starts_at: "2026-06-01 10:00")
    patch day_working_hours_operations_employee_path(@employee), params: { weekday: 1, enabled: false }, as: :json
    assert_response :conflict
    assert @employee.employee_working_hours.where(weekday: 1).exists?
    assert_no_difference "Employee.count" do
      delete operations_employee_path(@employee), as: :json
      assert_response :conflict
    end
  end

  test "deleting an employee without appointments also removes assignments and hours" do
    assert_difference "Employee.count", -1 do
      delete operations_employee_path(@employee), as: :json
      assert_response :success
    end
    assert_empty EmployeeWorkingHour.where(employee_id: @employee.id)
    assert_empty EmployeeService.where(employee_id: @employee.id)
  end

  test "service category can be created with the service atomically and searched in the index" do
    post operations_services_path, params: { service: { name: "Servicio con categoría", new_category_name: "Uñas", price: 200, duration_minutes: 30 } }, as: :json
    assert_response :created
    service = Service.find(response.parsed_body["id"])
    assert_equal "Uñas", service.category.name
    get datatable_operations_services_path, params: { length: 10, search: { value: "Uñas" } }, as: :json
    assert_response :success
    assert_equal "Uñas", response.parsed_body["data"].first[1]
    assert_no_difference "ServiceCategory.count" do
      post operations_services_path, params: { service: { name: "Inválido", new_category_name: "No persistir", price: -5, duration_minutes: 30 } }, as: :json
      assert_response :unprocessable_entity
    end
  end

  test "single save persists name hours absences and assigned services" do
    other = create_service!(name: "Tinte")
    patch operations_employee_path(@employee), params: {
      employee: { name: "Yazmin", active: true },
      hours: {
        "1" => { enabled: true, starts_at: "10:00", ends_at: "20:00" },
        "2" => { enabled: false },
        "3" => { enabled: true, starts_at: "09:00", ends_at: "18:00" },
        "4" => { enabled: true, starts_at: "09:00", ends_at: "18:00" },
        "5" => { enabled: true, starts_at: "09:00", ends_at: "18:00" },
        "6" => { enabled: false },
        "7" => { enabled: false }
      },
      service_ids: [ "", other.id ],
      time_off: { starts_at: "2026-06-10T09:00", ends_at: "2026-06-10T18:00", reason: "Vacaciones" }
    }, as: :json
    assert_response :success
    @employee.reload
    assert_equal "Yazmin", @employee.name
    assert_equal [ [ 1, "10:00:00", "20:00:00" ], [ 3, "09:00:00", "18:00:00" ], [ 4, "09:00:00", "18:00:00" ], [ 5, "09:00:00", "18:00:00" ] ],
      @employee.employee_working_hours.order(:weekday, :starts_at).pluck(:weekday, :starts_at, :ends_at)
    assert_equal [ other.id ], @employee.employee_services.pluck(:service_id)
    absence = @employee.employee_time_offs.last
    assert_equal "Vacaciones", absence.reason
    assert_equal "2026-06-10T09:00:00", absence.starts_at.in_time_zone(BusinessSetting.current!.time_zone).strftime("%Y-%m-%dT%H:%M:%S")
  end

  test "failed absence on the editor rolls back the other changes" do
    book_appointment!(employee: @employee, client: create_client!, services: [ @service ], starts_at: "2026-06-01 10:00")
    original_name = @employee.name
    original_hours = @employee.employee_working_hours.order(:weekday).pluck(:weekday, :starts_at, :ends_at)
    patch operations_employee_path(@employee), params: {
      employee: { name: "No debe persistir" },
      hours: {
        "1" => { enabled: true, starts_at: "09:00", ends_at: "18:00" },
        "2" => { enabled: true, starts_at: "09:00", ends_at: "18:00" },
        "3" => { enabled: true, starts_at: "09:00", ends_at: "18:00" },
        "4" => { enabled: true, starts_at: "09:00", ends_at: "18:00" },
        "5" => { enabled: true, starts_at: "09:00", ends_at: "18:00" },
        "6" => { enabled: false },
        "7" => { enabled: false }
      },
      service_ids: [ "" ],
      time_off: { starts_at: "2026-06-01T09:00", ends_at: "2026-06-01T12:00", reason: "Conflicto" }
    }, as: :json
    assert_response :conflict
    @employee.reload
    assert_equal original_name, @employee.name
    assert_equal original_hours, @employee.employee_working_hours.order(:weekday).pluck(:weekday, :starts_at, :ends_at)
    assert_equal [ @service.id ], @employee.employee_services.pluck(:service_id)
    assert_equal 0, @employee.employee_time_offs.count
  end

  test "employees cannot delete employees or change categories" do
    sign_in users(:employee)
    delete operations_employee_path(@employee), as: :json
    assert_response :forbidden
    patch operations_service_path(@service), params: { service: { new_category_name: "Prohibida" } }, as: :json
    assert_response :forbidden
  end
end
