# frozen_string_literal: true

module Api
  module V1
    class SessionsController < ApplicationController
      skip_before_action :authenticate_user!, only: %i[create destroy]
      skip_before_action :verify_authenticity_token, only: %i[create destroy]
      skip_before_action :allow_browser, only: %i[create destroy], raise: false

      def create
        user = User.find_by(email: session_params[:email].to_s.downcase.strip)

        if user&.valid_password?(session_params[:password])
          sign_in(user)
          render json: { success: true, user: user_json(user) }, status: :ok
        else
          render json: {
            success: false,
            message: "Email o contraseña incorrectos"
          }, status: :unauthorized
        end
      end

      def destroy
        sign_out(current_user) if user_signed_in?
        head :no_content
      end

      private

      def session_params
        params.permit(:email, :password)
      end

      def user_json(user)
        {
          id: user.id,
          email: user.email,
          full_name: user.full_name,
          rol_name: user.rol_name
        }
      end
    end
  end
end
