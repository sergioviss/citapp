# frozen_string_literal: true

require "test_helper"

class DayScheduleTest < ActiveSupport::TestCase
  setup do
    @date = Date.new(2026, 6, 1)
    @employee = create_employee!(hours: [
      { weekday: 1, starts_at: "09:00", ends_at: "13:00" },
      { weekday: 1, starts_at: "14:00", ends_at: "18:00" }
    ])
  end

  test "nonworking hours breaks and overlapping absence intervals are merged" do
    @employee.employee_time_offs.create!(created_by: users(:admin), starts_at: Time.find_zone!("America/Hermosillo").parse("2026-06-01 12:30"),
      ends_at: Time.find_zone!("America/Hermosillo").parse("2026-06-01 14:30"))
    assert_equal [
      { start: "2026-06-01T00:00:00", end: "2026-06-01T09:00:00" },
      { start: "2026-06-01T12:30:00", end: "2026-06-01T14:30:00" },
      { start: "2026-06-01T18:00:00", end: "2026-06-02T00:00:00" }
    ], schedule
  end

  test "no schedule and inactive employees are unavailable for the entire day" do
    @employee.update!(active: false)
    assert_equal [ { start: "2026-06-01T00:00:00", end: "2026-06-02T00:00:00" } ], schedule
    @employee.update!(active: true)
    @employee.employee_working_hours.destroy_all
    @employee.reload
    assert_equal [ { start: "2026-06-01T00:00:00", end: "2026-06-02T00:00:00" } ], schedule
  end

  test "24 hour schedule and absences spanning midnight are clipped to the selected date" do
    @employee.employee_working_hours.destroy_all
    @employee.employee_working_hours.create!(weekday: 1, starts_at: "00:00", ends_at: "24:00")
    @employee.reload
    assert_empty schedule
    zone = Time.find_zone!("America/Hermosillo")
    @employee.employee_time_offs.create!(created_by: users(:admin), starts_at: zone.parse("2026-05-31 20:00"), ends_at: zone.parse("2026-06-01 08:00"))
    @employee.employee_time_offs.create!(created_by: users(:admin), starts_at: zone.parse("2026-06-01 22:00"), ends_at: zone.parse("2026-06-02 12:00"))
    assert_equal [
      { start: "2026-06-01T00:00:00", end: "2026-06-01T08:00:00" },
      { start: "2026-06-01T22:00:00", end: "2026-06-02T00:00:00" }
    ], schedule
  end

  private

  def schedule
    Availability::DaySchedule.call(employee: @employee, date: @date, time_zone: "America/Hermosillo")
  end
end
