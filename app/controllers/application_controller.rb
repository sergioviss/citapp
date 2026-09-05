class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Redirects an unauthenticated user to the sign-in view
  def authenticate_user
    return if user_signed_in?

    redirect_to '/users/sign_in', alert: 'Debes iniciar sesión para continuar.'
  end

end
