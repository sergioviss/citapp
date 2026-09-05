# frozen_string_literal: true

class ThemeController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:update]
  skip_before_action :authenticate_user!, only: [:update], raise: false

  # PATCH /theme/update
  # Recibe la configuración del tema y la guarda en config/theme.yml
  def update
    config_path = Rails.root.join("config", "theme.yml")

    # Leer configuración actual
    current_config = if File.exist?(config_path)
      YAML.safe_load(File.read(config_path), permitted_classes: [Symbol]) || {}
    else
      {}
    end

    # Actualizar sección de tema si viene en los params
    if params[:theme].present?
      current_config["theme"] ||= {}
      current_config["theme"]["preset"] = params[:theme][:preset] if params[:theme][:preset].present?

      if params[:theme][:custom_colors].present?
        current_config["theme"]["custom_colors"] ||= {}
        params[:theme][:custom_colors].each do |key, value|
          current_config["theme"]["custom_colors"][key.to_s] = value if value.present?
        end
      end
    end

    # Actualizar sección de layout si viene en los params
    if params[:layout_config].present?
      current_config["layout"] ||= {}
      current_config["layout"]["scheme"]    = params[:layout_config][:scheme]    if params[:layout_config][:scheme].present?
      current_config["layout"]["menu"]      = params[:layout_config][:menu]      if params[:layout_config][:menu].present?
      current_config["layout"]["style"]     = params[:layout_config][:style]     if params[:layout_config][:style].present?
      current_config["layout"]["direction"] = params[:layout_config][:direction] if params[:layout_config][:direction].present?
      current_config["layout"]["animation"] = params[:layout_config][:animation] if params[:layout_config].key?(:animation)
      current_config["layout"]["navbar"]    = params[:layout_config][:navbar]    if params[:layout_config][:navbar].present?
      current_config["layout"]["semidark"]  = ActiveModel::Type::Boolean.new.cast(params[:layout_config][:semidark]) if params[:layout_config].key?(:semidark)
    end

    # Actualizar sección de logo si viene en los params
    if params[:logo].present?
      current_config["logo"] ||= {}
      current_config["logo"]["text"]       = params[:logo][:text]       if params[:logo].key?(:text)
      current_config["logo"]["image"]      = params[:logo][:image]      if params[:logo].key?(:image)
      current_config["logo"]["show_image"] = ActiveModel::Type::Boolean.new.cast(params[:logo][:show_image]) if params[:logo].key?(:show_image)
    end

    # Escribir archivo con header
    yaml_content = <<~HEADER
      # =============================================================================
      # Configuración de Tema del Template Customizer
      # Este archivo se genera/actualiza automáticamente desde el panel de customización.
      # Se commitea a git para que la configuración viaje con el proyecto.
      # =============================================================================
    HEADER
    yaml_content += current_config.to_yaml.sub("---\n", "")

    File.write(config_path, yaml_content)

    render json: { success: true, config: current_config }
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end
end
