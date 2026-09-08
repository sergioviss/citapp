# frozen_string_literal: true

require "test_helper"

class AppointmentEditorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:receptionist)
    @client = create_client!
    @service = create_service!(duration_minutes: 30, price: 100)
    @extra = create_service!(name: "Complemento", duration_minutes: 45, price: 200)
    @employee = create_employee!(services: [ @service, @extra ])
    @other = create_employee!(services: [ @service, @extra ])
    @appointment = book_appointment!(employee: @employee, client: @client, services: [ @service ], starts_at: "2026-06-01 10:00")
  end

  test "creates client and multi service appointment atomically" do
    assert_difference [ "Client.count", "Appointment.count" ] do
      post operations_appointments_path, params: { appointment: { new_client: { name: "Nuevo cliente", phone: "6624441234" },
        employee_id: @employee.id, service_ids: [ @service.id, @extra.id ], starts_at: "2026-06-01T14:00", ends_at: "2026-06-01T15:15" } }, as: :json
      assert_response :created
    end
    appointment = Appointment.find(response.parsed_body["id"])
    assert_equal "Nuevo cliente", appointment.client.name
    assert_equal 75.minutes, appointment.ends_at - appointment.starts_at
    assert_equal 2, appointment.appointment_services.count
  end

  test "invalid booking rolls back new client and appointment" do
    assert_no_difference [ "Client.count", "Appointment.count" ] do
      post operations_appointments_path, params: { appointment: { new_client: { name: "No guardar", phone: "6624441234" },
        employee_id: @employee.id, service_ids: [ @service.id ], starts_at: "2026-06-01T10:00" } }, as: :json
      assert_response :conflict
    end
  end

  test "editing services preserves quoted snapshots and changes duration employee client and notes" do
    @service.update!(price: 900, duration_minutes: 60)
    patch reschedule_operations_appointment_path(@appointment), params: { appointment: {
      employee_id: @other.id, starts_at: "2026-06-01T14:00", service_ids: [ @service.id, @extra.id ],
      new_client: { name: "Cliente corregido", phone: "6624445678" }, notes: "Actualizada en diálogo"
    } }, as: :json
    assert_response :success
    @appointment.reload
    assert_equal @other.id, @appointment.employee_id
    assert_equal "Cliente corregido", @appointment.client.name
    assert_equal "Actualizada en diálogo", @appointment.notes
    assert_equal 75.minutes, @appointment.ends_at - @appointment.starts_at
    assert_equal 100, @appointment.appointment_services.first.quoted_price
  end

  test "cross employee move rejects an occupied destination without changing original appointment" do
    book_appointment!(employee: @other, client: @client, services: [ @service ], starts_at: "2026-06-01 11:00")
    original = @appointment.reload.attributes
    patch reschedule_operations_appointment_path(@appointment), params: { appointment: {
      employee_id: @other.id, starts_at: "2026-06-01T11:00", ends_at: "2026-06-01T11:30"
    } }, as: :json
    assert_response :conflict
    assert_equal original, @appointment.reload.attributes
  end

  test "editing a billed appointment preserves its client and services" do
    Sales::SaveDraft.call(actor: users(:receptionist), client_id: @client.id, appointment_id: @appointment.id,
      items: @appointment.appointment_services.map { |line| { service_id: line.service_id, appointment_service_id: line.id } })
    patch reschedule_operations_appointment_path(@appointment), params: { appointment: {
      starts_at: "2026-06-01T14:00", service_ids: [ @extra.id ]
    } }, as: :json
    assert_response :unprocessable_entity
    assert_equal [ @service.id ], @appointment.appointment_services.pluck(:service_id)
    patch reschedule_operations_appointment_path(@appointment), params: { appointment: {
      starts_at: "2026-06-01T14:00", employee_id: @other.id
    } }, as: :json
    assert_response :success
  end
end
