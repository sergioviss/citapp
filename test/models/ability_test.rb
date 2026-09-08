# frozen_string_literal: true

require "test_helper"

class AbilityTest < ActiveSupport::TestCase
  test "admin can manage everything" do
    ability = Ability.new(users(:admin))
    assert ability.can?(:manage, Appointment)
    assert ability.can?(:manage, Sale)
    assert ability.can?(:manage, Payment)
  end

  test "receptionist manages operations but not users" do
    ability = Ability.new(users(:receptionist))
    assert ability.can?(:create, Appointment)
    assert ability.can?(:create, Sale)
    assert ability.can?(:create, Payment)
    assert ability.can?(:update, Employee)
    assert ability.can?(:update, Sale)
    assert_not ability.can?(:destroy, Sale)
    assert_not ability.can?(:destroy, Client)
    assert_not ability.can?(:destroy, Service)
    assert_not ability.can?(:manage, User)
  end

  test "employee can only complete or mark no-show on own appointments" do
    service = create_service!
    employee = create_employee!(user: users(:employee), services: [ service ])
    other = create_employee!(services: [ service ])
    client = create_client!
    own = book_appointment!(employee: employee, client: client, services: [ service ], starts_at: local_slot("2026-06-01", 10))
    foreign = book_appointment!(employee: other, client: client, services: [ service ], starts_at: local_slot("2026-06-01", 10))

    ability = Ability.new(users(:employee))
    assert ability.can?(:read, own)
    assert ability.can?(:complete, own)
    assert ability.can?(:mark_no_show, own)
    assert_not ability.can?(:update, own)
    assert_not ability.can?(:complete, foreign)
    assert_not ability.can?(:create, Appointment)
  end

  test "inactive users have no abilities" do
    ability = Ability.new(users(:inactive))
    assert_not ability.can?(:read, Appointment)
  end
end
