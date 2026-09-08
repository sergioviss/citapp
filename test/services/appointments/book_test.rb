# frozen_string_literal: true

require "test_helper"

class Appointments::BookTest < ActiveSupport::TestCase
  setup do
    @service = create_service!(name: "Corte", duration_minutes: 30, price: 150)
    @employee = create_employee!(services: [ @service ])
    @client = create_client!
  end

  test "creates appointment and service snapshots in one transaction" do
    appointment = book_appointment!(
      employee: @employee,
      client: @client,
      services: [ @service ],
      starts_at: local_slot("2026-06-01", 10)
    )

    assert appointment.persisted?
    assert_equal "scheduled", appointment.status
    assert_equal "MXN", appointment.currency
    assert_equal 1, appointment.appointment_services.count
    line = appointment.appointment_services.first
    assert_equal "Corte", line.service_name
    assert_equal 30, line.duration_minutes
    assert_equal BigDecimal("150.00"), line.quoted_price
  end

  test "keeps quoted snapshots after catalog price changes" do
    appointment = book_appointment!(
      employee: @employee,
      client: @client,
      services: [ @service ],
      starts_at: local_slot("2026-06-01", 10)
    )
    @service.update!(price: 999, name: "Corte premium", duration_minutes: 90)

    line = appointment.appointment_services.reload.first
    assert_equal "Corte", line.service_name
    assert_equal 30, line.duration_minutes
    assert_equal BigDecimal("150.00"), line.quoted_price
  end

  test "rejects inactive employees" do
    @employee.update!(active: false)

    error = assert_raises(Domain::ValidationError) do
      book_appointment!(employee: @employee, client: @client, services: [ @service ], starts_at: local_slot("2026-06-01", 10))
    end
    assert_match(/activo/i, error.message)
  end

  test "rejects services the employee cannot perform" do
    other = create_service!(name: "Tinte", duration_minutes: 30, price: 200)

    error = assert_raises(Domain::ValidationError) do
      book_appointment!(employee: @employee, client: @client, services: [ other ], starts_at: local_slot("2026-06-01", 10))
    end
    assert_match(/no puede realizar/i, error.message)
  end

  test "rejects bookings without services" do
    error = assert_raises(Domain::ValidationError) do
      Appointments::Book.call(
        actor: users(:receptionist),
        client_id: @client.id,
        employee_id: @employee.id,
        service_ids: [],
        starts_at: local_slot("2026-06-01", 10)
      )
    end
    assert_match(/al menos un servicio/i, error.message)
  end

  test "rejects intervals shorter than the reserved durations" do
    error = assert_raises(Domain::ValidationError) do
      book_appointment!(
        employee: @employee,
        client: @client,
        services: [ @service ],
        starts_at: local_slot("2026-06-01", 10),
        ends_at: local_slot("2026-06-01", 10, 10)
      )
    end
    assert_match(/duraciones/i, error.message)
  end

  test "rejects times outside working hours" do
    error = assert_raises(Domain::ValidationError) do
      book_appointment!(employee: @employee, client: @client, services: [ @service ], starts_at: local_slot("2026-06-01", 7))
    end
    assert_match(/horario laboral/i, error.message)
  end

  test "rejects bookings that overlap time off" do
    Employees::RecordTimeOff.call(
      actor: users(:admin),
      employee: @employee,
      starts_at: local_slot("2026-06-01", 9),
      ends_at: local_slot("2026-06-01", 18)
    )

    error = assert_raises(Domain::ValidationError) do
      book_appointment!(employee: @employee, client: @client, services: [ @service ], starts_at: local_slot("2026-06-01", 10))
    end
    assert_match(/ausencia/i, error.message)
  end

  test "allows a 24:00 working-hour boundary" do
    @employee.employee_working_hours.delete_all
    hour = @employee.employee_working_hours.create!(weekday: 1, starts_at: "22:00", ends_at: "23:59:59")
    EmployeeWorkingHour.connection.execute(
      EmployeeWorkingHour.sanitize_sql_array([ "UPDATE employee_working_hours SET ends_at = '24:00:00' WHERE id = ?", hour.id ])
    )
    @employee.employee_working_hours.reload

    appointment = book_appointment!(
      employee: @employee,
      client: @client,
      services: [ @service ],
      starts_at: local_slot("2026-06-01", 23),
      ends_at: "2026-06-02 00:00"
    )
    assert appointment.persisted?
  end

  test "rejects nonexistent DST local times" do
    BusinessSetting.current!.update!(time_zone: "America/New_York")

    error = assert_raises(Domain::ValidationError) do
      book_appointment!(
        employee: @employee,
        client: @client,
        services: [ @service ],
        starts_at: "2026-03-08 02:30"
      )
    end
    assert_match(/no existe/i, error.message)
  ensure
    BusinessSetting.current!.update!(time_zone: "America/Mexico_City")
  end

  test "rejects ambiguous DST local times" do
    BusinessSetting.current!.update!(time_zone: "America/New_York")

    error = assert_raises(Domain::ValidationError) do
      book_appointment!(
        employee: @employee,
        client: @client,
        services: [ @service ],
        starts_at: "2026-11-01 01:30"
      )
    end
    assert_match(/ambigua/i, error.message)
  ensure
    BusinessSetting.current!.update!(time_zone: "America/Mexico_City")
  end

  test "forbids employees from booking" do
    assert_raises(Domain::Forbidden) do
      book_appointment!(
        actor: users(:employee),
        employee: @employee,
        client: @client,
        services: [ @service ],
        starts_at: local_slot("2026-06-01", 10)
      )
    end
  end
end
