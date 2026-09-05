# config/initializers/mission_control_jobs.rb

# 1. Desactivamos el HTTP Basic Auth que viene por defecto
# Esto evita que te pida usuario/contraseña extra y use tu sesión de Devise
MissionControl::Jobs.http_basic_auth_enabled = false

# 2. Hacemos que herede de tu ApplicationController
# Esto es útil para que el dashboard use tus mismos helpers o configuraciones
Rails.application.configure do
  config.mission_control.jobs.base_controller_class = "ApplicationController"
end