require "test_helper"

class DatabaseAuditTest < ActiveSupport::TestCase
  setup do
    @actor = users(:admin)
    @client = create_client!
    @service = create_service!(price: 100)
    @employee = create_employee!(services: [ @service ])
  end

  def sale!
    Sales::SaveDraft.call(actor: @actor, client_id: @client.id,
      items: [ { service_id: @service.id, quantity: 1, unit_price: 100 } ])
  end

  def appointment!
    book_appointment!(employee: @employee, client: @client, services: [ @service ],
      starts_at: "2026-06-01 10:00")
  end

  test "stale appointment cannot replace a completed status" do
    original = appointment!
    stale = Appointment.find(original.id)
    Appointments::ChangeStatus.call(actor: @actor, appointment: original, status: "completed")
    assert_raises(Domain::ValidationError) do
      Appointments::ChangeStatus.call(actor: @actor, appointment: stale, status: "cancelled")
    end
  end

  test "stale appointment cannot reschedule completed history" do
    original = appointment!
    stale = Appointment.find(original.id)
    Appointments::ChangeStatus.call(actor: @actor, appointment: original, status: "completed")
    assert_raises(Domain::ValidationError) do
      Appointments::Reschedule.call(actor: @actor, appointment: stale, starts_at: "2026-06-01 16:00")
    end
  end

  test "cancel result keeps historical totals immutable" do
    sale = sale!
    Sales::Publish.call(actor: @actor, sale: sale)
    cancelled = Sales::Cancel.call(actor: @actor, sale: sale)
    assert_not cancelled.update(subtotal: 999), "Cancelled sale accepted a new historical total"
  end

  test "cached draft association cannot change a posted line" do
    draft = sale!
    line = draft.sale_items.first
    line.sale
    Sales::Publish.call(actor: @actor, sale: draft)
    assert_not line.update(unit_price: 999), "Cached draft allowed mutation after publication"
  end

  test "weekly hours support midnight via the application service" do
    slots = [ { weekday: 1, starts_at: "22:00", ends_at: "24:00" } ]
    result = Employees::ReplaceWorkingHours.call(actor: @actor, employee: @employee, slots: slots)
    assert_equal 86400, result.first.ends_at_seconds
  end

  test "seeds preserve an existing business configuration and inactive account" do
    settings = BusinessSetting.current!
    settings.update!(time_zone: "America/Hermosillo")
    inactive = users(:inactive)
    old_email = ENV["ADMIN_EMAIL"]
    ENV["ADMIN_EMAIL"] = inactive.email
    load Rails.root.join("db/seeds.rb")
    assert_equal "America/Hermosillo", settings.reload.time_zone
    assert_not inactive.reload.active?
  ensure
    ENV["ADMIN_EMAIL"] = old_email
  end
end
