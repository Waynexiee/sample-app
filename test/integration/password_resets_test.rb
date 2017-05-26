require 'test_helper'

class PasswordResetsTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end
  def setup
    ActionMailer::Base.deliveries.clear
    @user = users(:michael)
  end

  test "password resets" do
    get new_password_reset_path
    assert_template 'password_resets/new'
  #   invalid email address
    post password_resets_path, params: { password_reset: { email: "" } }
    assert_not flash.empty?
    assert_template 'password_resets/new'
  #   valid email address
    post password_resets_path,
      params: { password_reset: { email: @user.email }}
    assert_not_equal @user.reset_digest, @user.reload.reset_digest
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_not flash.empty?
    assert_redirected_to root_url
  #   password reset
    user = assigns(:user)
  #   wrong email address
    get edit_password_reset_path(user.reset_token, email: "")
    assert_redirected_to root_url
  #   unactivated user
    user.toggle!(:activated)
    get edit_password_reset_path(user.reset_token, email: user.email)
    assert_redirected_to root_url
    user.toggle!(:activated)
  #   wrong token
    get edit_password_reset_path('wrong token', email: user.email)
    assert_redirected_to root_url
  #   all right
    get edit_password_reset_path(user.reset_token, email: user.email)
    assert_template 'password_resets/edit'
    assert_select "input[name=email][type=hidden][value=?]", user.email
  #   password doesn't match password_confirmation
    patch password_reset_path(user.reset_token),
          params: { email: user.email,
                    user: { password: "foobaz",
                            password_confirmation: "barqux"}}
    assert_select 'div#error_explanation'
  #   empty password
    patch password_reset_path(user.reset_token),
          params: { email: user.email,
                    user: { password: "",
                            password_confirmation: ""}}
    assert_select 'div#error_explanation'
  #   both are valid
    patch password_reset_path(user.reset_token),
          params: { email: user.email,
                    user: { password: "foobaz",
                            password_confirmation: "foobaz"}}
    assert is_logged_in?
    assert_not flash.empty?
    assert_redirected_to user
  end

  test "expired token" do
    get new_password_reset_path
    post password_resets_path,
         params: { password_reset: { email: @user.email } }
    @user = assigns(:user)
    @user.update_attribute(:reset_sent_at, 3.hours.ago)
    patch password_reset_path(@user.reset_token),
          params: { email: @user.email, user: { password: "foobar",
                                                password_confirmation: "foobar" }}
    assert_response :redirect
    follow_redirect!
    assert_match /expired/i, response.body
  end
end
