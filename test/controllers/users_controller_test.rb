# frozen_string_literal: true

require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  BROWSER_HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
  }.freeze

  setup do
    sign_in users(:admin)
  end

  test "destroy does not deactivate the last administrator" do
    delete user_path(users(:admin)), headers: BROWSER_HEADERS

    assert_redirected_to users_url
    assert_equal User::LAST_ACTIVE_ADMIN_MESSAGE, flash[:alert]
    assert users(:admin).reload.active?
  end

  test "update does not deactivate the last administrator" do
    patch user_path(users(:admin)), params: {
      user: { active: false }
    }, headers: BROWSER_HEADERS

    assert_response :unprocessable_entity
    assert users(:admin).reload.active?
  end

  test "update does not demote the last administrator" do
    patch user_path(users(:admin)), params: {
      user: { role_id: roles(:receptionist).id }
    }, headers: BROWSER_HEADERS

    assert_response :unprocessable_entity
    assert users(:admin).reload.admin?
  end

  test "datatable actions use the shared table icon buttons" do
    get datatable_users_path, params: { length: 10 }, as: :json
    assert_response :success
    actions = response.parsed_body.fetch("data").first.fetch("actions")
    assert_includes actions, "ops-table-actions"
    assert_includes actions, "ops-action-icon"
    assert_includes actions, "ops-action-icon--danger"
    assert_includes actions, "datatable-action-edit"
    assert_includes actions, "datatable-action-delete"
  end
end
