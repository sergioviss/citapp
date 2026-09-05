class AuthController < ApplicationController
    def auth_boxed_signin
       render layout: "auth", :template =>'auth/boxed-signin'
    end

    def auth_boxed_signup
       render layout: "auth", :template =>'auth/boxed-signup'
    end

    def auth_boxed_lockscreen
       render layout: "auth", :template =>'auth/boxed-lockscreen'
    end

    def auth_boxed_password_reset
       render layout: "auth", :template =>'auth/boxed-password-reset'
    end

    def auth_cover_login
       render layout: "auth", :template =>'auth/cover-login'
    end

    def auth_cover_register
       render layout: "auth", :template =>'auth/cover-register'
    end

    def auth_cover_lockscreen
       render layout: "auth", :template =>'auth/cover-lockscreen'
    end

    def auth_cover_password_reset
       render layout: "auth", :template =>'auth/cover-password-reset'
    end
end
