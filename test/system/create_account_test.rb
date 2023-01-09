require "application_system_test_case"

class CreateAccountTest < ApplicationSystemTestCase
  include ActionMailer::TestHelper
  setup do
    visit root_path
  end

  test "user can see a google sign in button" do
    visit new_user_session_path
    click_on "Registrarte"
    assert_text "Registro"
    assert_selector(:xpath, './/button[@class="google-sign-in-button"]')
  end

  test "user can sign up with email and password" do
    visit new_user_registration_path

    assert_text "Registrarte con tu correo electrónico"
    fill_in "Correo electrónico", with: 'alice@test.com'
    fill_in "Nueva contraseña", with: 'alice123'
    fill_in "Confirma tu nueva contraseña", with: 'alice123'

    # expect email to be sent
    assert_emails 1 do
      click_on "Registrarte"
    end

    # going to email confirmation page without token expect error
    visit user_confirmation_path(confirmation_token: 'invalid_token')
    assert_current_path(user_confirmation_path, ignore_query: true)
    assert_text 'Reenviar instrucciones de confirmación'

    # get token and confirm account
    token = User.find_by(email: 'alice@test.com').confirmation_token
    visit user_confirmation_url(confirmation_token: token)

    # expect to be signed in
    assert_current_path(root_path)
    click_actions_menu
    within_actions_menu do
      assert_text "alice@test.com"
    end
  end

  test "user can't sign up due to incorrect confirmation password" do
    visit new_user_registration_path

    assert_text "Registrarte con tu correo electrónico"
    fill_in "Correo electrónico", with: 'alice@test.com'
    fill_in "Nueva contraseña", with: 'alice123'
    fill_in "Confirma tu nueva contraseña", with: 'alice321'
    click_on "Registrarte"

    within('.form-input-container', text: 'Confirma tu nueva contraseña') do
      assert_text "No coincide"
    end
  end

  test "user can't sign up due to email already in use" do
    visit new_user_registration_path
    create_user(email: 'bob@test.com')

    assert_text "Registrarte con tu correo electrónico"
    fill_in "Correo electrónico", with: 'bob@test.com'
    fill_in "Nueva contraseña", with: 'bob321'
    fill_in "Confirma tu nueva contraseña", with: 'bob321'
    click_on "Registrarte"

    within('.form-input-container', text: 'Correo electrónico') do
      assert_text "Ya está en uso"
    end
  end
end
