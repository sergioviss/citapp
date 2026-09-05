# frozen_string_literal: true

module ThemeHelper
  # Mapeo de temas predefinidos con sus colores
  COLOR_THEMES = {
    "default"   => { primary: "#4361ee", secondary: "#805dca", success: "#00ab55", danger: "#e7515a", warning: "#e2a03f", info: "#2196f3" },
    "emerald"   => { primary: "#00ab55", secondary: "#2196f3", success: "#00ab55", danger: "#ff6f6f", warning: "#f5a623", info: "#2196f3" },
    "corporate" => { primary: "#4b6bfb", secondary: "#7b92b2", success: "#2dd4bf", danger: "#ff6b6b", warning: "#fbbd23", info: "#3abff8" },
    "sunset"    => { primary: "#ff865b", secondary: "#fd6f9c", success: "#51cf66", danger: "#ff6b6b", warning: "#fcc419", info: "#22b8cf" },
    "cyberpunk" => { primary: "#ff7598", secondary: "#75d1f0", success: "#51cf66", danger: "#ff6b6b", warning: "#ffd43b", info: "#4cc9f0" },
    "forest"    => { primary: "#1eb854", secondary: "#1db990", success: "#1eb854", danger: "#e55353", warning: "#e5a50a", info: "#3fc1c9" },
    "dracula"   => { primary: "#ff79c6", secondary: "#bd93f9", success: "#50fa7b", danger: "#ff5555", warning: "#f1fa8c", info: "#8be9fd" },
    "nord"      => { primary: "#5e81ac", secondary: "#88c0d0", success: "#a3be8c", danger: "#bf616a", warning: "#ebcb8b", info: "#81a1c1" },
    "luxury"    => { primary: "#dca54c", secondary: "#152747", success: "#4ade80", danger: "#fb7185", warning: "#dca54c", info: "#38bdf8" },
    "aqua"      => { primary: "#09ecf3", secondary: "#966fb3", success: "#51cf66", danger: "#ff6b6b", warning: "#ffe066", info: "#09ecf3" },
    "autumn"    => { primary: "#8c0327", secondary: "#d85251", success: "#2dd4bf", danger: "#8c0327", warning: "#f59e0b", info: "#2563eb" },
    "coffee"    => { primary: "#db924b", secondary: "#6bc5f2", success: "#4ade80", danger: "#fb7185", warning: "#db924b", info: "#6bc5f2" },
    "winter"    => { primary: "#047aff", secondary: "#463aa2", success: "#4ade80", danger: "#fb7185", warning: "#f59e0b", info: "#047aff" },
    "lemonade"  => { primary: "#519903", secondary: "#e9e92f", success: "#519903", danger: "#e7515a", warning: "#e9e92f", info: "#2196f3" },
    "night"     => { primary: "#38bdf8", secondary: "#818cf8", success: "#4ade80", danger: "#fb7185", warning: "#fbbf24", info: "#38bdf8" }
  }.freeze

  # Lee la configuración del tema desde config/theme.yml
  def theme_config
    @theme_config ||= begin
      config_path = Rails.root.join("config", "theme.yml")
      if File.exist?(config_path)
        YAML.safe_load(File.read(config_path), permitted_classes: [Symbol]) || {}
      else
        {}
      end
    end
  end

  # Obtiene los colores activos según el preset o custom
  def active_theme_colors
    theme = theme_config.dig("theme", "preset") || "default"
    if theme == "custom"
      custom = theme_config.dig("theme", "custom_colors") || {}
      {
        primary:   custom["primary"]   || "#4361ee",
        secondary: custom["secondary"] || "#805dca",
        success:   custom["success"]   || "#00ab55",
        danger:    custom["danger"]    || "#e7515a",
        warning:   custom["warning"]   || "#e2a03f",
        info:      custom["info"]      || "#2196f3"
      }
    else
      COLOR_THEMES[theme] || COLOR_THEMES["default"]
    end
  end

  # Nombre del preset activo
  def active_theme_preset
    theme_config.dig("theme", "preset") || "default"
  end

  # Genera un bloque <style> con CSS custom properties para los colores del tema activo
  def theme_css_variables_tag
    colors = active_theme_colors
    tag.style(<<~CSS, nonce: content_security_policy_nonce)
      :root {
        --color-primary: #{colors[:primary]};
        --color-secondary: #{colors[:secondary]};
        --color-success: #{colors[:success]};
        --color-danger: #{colors[:danger]};
        --color-warning: #{colors[:warning]};
        --color-info: #{colors[:info]};
      }
    CSS
  end

  # Configuración de layout desde el archivo
  def theme_layout_config
    layout = theme_config["layout"] || {}
    {
      scheme:    layout["scheme"]    || "light",
      menu:      layout["menu"]      || "vertical",
      style:     layout["style"]     || "full",
      direction: layout["direction"] || "ltr",
      animation: layout["animation"] || "",
      navbar:    layout["navbar"]    || "navbar-sticky",
      semidark:  layout["semidark"]  || false,
      logo: {
        text:       theme_config.dig("logo", "text")       || "VRISTO",
        image:      theme_config.dig("logo", "image")      || "/assets/images/logo.svg",
        show_image: theme_config.dig("logo", "show_image") != false
      }
    }
  end

  # Data attributes para inyectar en el HTML como configuración inicial de Alpine
  def theme_data_json
    layout = theme_layout_config
    {
      theme: layout[:scheme],
      menu: layout[:menu],
      layout: layout[:style],
      rtlClass: layout[:direction],
      animation: layout[:animation],
      navbar: layout[:navbar],
      semidark: layout[:semidark],
      colorTheme: active_theme_preset,
      customColors: active_theme_colors,
      logo: layout[:logo]
    }.to_json
  end

  # Genera el atributo data-theme para el <html>
  def theme_data_attribute
    active_theme_preset
  end

  def theme_logo_text
    theme_layout_config.dig(:logo, :text).presence
  end

  # Ruta pública del logo solo si el archivo existe (evita imágenes rotas).
  def theme_logo_image_src
    return unless theme_layout_config.dig(:logo, :show_image)

    src = theme_layout_config.dig(:logo, :image).to_s
    return if src.blank?

    public_path = Rails.root.join("public", src.delete_prefix("/"))
    src if File.exist?(public_path)
  end

  # Devuelve todos los temas disponibles como JSON para el customizer
  def available_themes_json
    COLOR_THEMES.to_json
  end
end
