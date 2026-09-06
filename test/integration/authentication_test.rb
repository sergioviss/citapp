# frozen_string_literal: true

require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  BROWSER_HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
  }.freeze

  test "Devise sign in rejects inactive accounts" do
    post user_session_path, params: {
      user: { email: users(:inactive).email, password: "Password1!" }
    }, headers: BROWSER_HEADERS

    get root_path, headers: BROWSER_HEADERS
    assert_redirected_to new_user_session_path
  end

  test "Devise sign in accepts active accounts" do
    post user_session_path, params: {
      user: { email: users(:admin).email, password: "Password1!" }
    }, headers: BROWSER_HEADERS

    get root_path, headers: BROWSER_HEADERS
    assert_response :success
    assert_select "h1", "Ventas"
  end

  test "API login rejects inactive accounts" do
    post api_v1_login_path, params: {
      email: users(:inactive).email,
      password: "Password1!"
    }, as: :json

    assert_response :unauthorized
    body = response.parsed_body
    assert_equal false, body["success"]
  end

  test "API login accepts active accounts" do
    post api_v1_login_path, params: {
      email: users(:admin).email,
      password: "Password1!"
    }, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal true, body["success"]
    assert_equal "admin", body.dig("user", "role_code")
  end
end
