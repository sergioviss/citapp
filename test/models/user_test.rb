# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "admin? uses role code" do
    assert users(:admin).admin?
    assert_not users(:receptionist).admin?
  end

  test "inactive users cannot authenticate" do
    user = users(:inactive)
    assert_not user.active_for_authentication?
    assert_equal :inactive, user.inactive_message
  end

  test "email uniqueness is case insensitive" do
    duplicate = User.new(
      full_name: "Otro",
      email: "ADMIN@example.com",
      password: "Password1!",
      password_confirmation: "Password1!",
      role: roles(:receptionist)
    )

    assert_not duplicate.valid?
  end

  test "deactivate! sets active false" do
    user = users(:receptionist)
    user.deactivate!
    assert_not user.reload.active?
  end

  test "the last active admin cannot be deactivated" do
    admin = users(:admin)

    error = assert_raises(ActiveRecord::RecordInvalid) { admin.deactivate! }

    assert_includes error.record.errors[:base], User::LAST_ACTIVE_ADMIN_MESSAGE
    assert admin.reload.active?
    assert admin.admin?
  end

  test "the last active admin cannot change role" do
    admin = users(:admin)

    assert_not admin.update(role: roles(:receptionist))
    assert_includes admin.errors[:base], User::LAST_ACTIVE_ADMIN_MESSAGE
    assert users(:admin).reload.admin?
  end

  test "an admin can be deactivated when another active admin remains" do
    extra_admin = create_admin_user!(email: "second-admin@example.com")

    users(:admin).deactivate!

    assert_not users(:admin).reload.active?
    assert extra_admin.reload.admin?
    assert extra_admin.active?
  end

  test "an admin can change role when another active admin remains" do
    create_admin_user!(email: "second-admin@example.com")

    assert users(:admin).update(role: roles(:receptionist))
    assert_equal "receptionist", users(:admin).reload.role_code
  end

  private

  def create_admin_user!(email:)
    User.create!(
      full_name: "Segundo Admin",
      email: email,
      password: "Password1!",
      password_confirmation: "Password1!",
      role: roles(:admin),
      active: true
    )
  end
end
