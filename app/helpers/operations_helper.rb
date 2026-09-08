# frozen_string_literal: true

module OperationsHelper
  def operations_catalog_row(record)
    values = case record
    when Client then [ record.name, record.phone, record.email ]
    when Service then [ record.name, record.category.name, "#{record.duration_minutes} min", number_to_currency(record.price), record.active? ? "Activo" : "Inactivo" ]
    else [ record.name, record.active? ? "Activo" : "Inactivo" ]
    end
    actions = []
    if record.is_a?(Employee) && can?(:update, record)
      actions << operations_action_icon(:edit, label: "Editar #{record.name}", path: edit_operations_employee_path(record))
    elsif can?(:update, record)
      actions << operations_action_icon(
        :edit,
        label: "Editar #{record.name}",
        button: true,
        data: { catalog_edit: record.attributes.slice("id", "name", "phone", "email", "price", "duration_minutes", "active", "category_id").to_json }
      )
    end
    if record.is_a?(Employee) && can?(:destroy, record)
      actions << operations_action_icon(:delete, label: "Eliminar #{record.name}", button: true, data: { employee_delete: operations_employee_path(record), employee_name: record.name })
    elsif (record.is_a?(Client) || record.is_a?(Service)) && can?(:destroy, record)
      kind = record.is_a?(Client) ? "cliente" : "servicio"
      path = record.is_a?(Client) ? operations_client_path(record) : operations_service_path(record)
      actions << operations_action_icon(:delete, label: "Eliminar #{record.name}", button: true,
        data: { catalog_delete: path, catalog_name: record.name, catalog_kind: kind })
    end
    values.map { |value| ERB::Util.html_escape(value.to_s) } + [ content_tag(:div, safe_join(actions), class: "ops-table-actions") ]
  end

  def operations_sale_row(sale)
    actions = [ operations_action_icon(:view, label: "Ver venta ##{sale.id}", path: operations_sale_path(sale)) ]
    if can?(:destroy, sale)
      actions << operations_action_icon(:delete, label: "Eliminar venta ##{sale.id}", button: true,
        data: { sale_delete: operations_sale_path(sale), sale_folio: "##{sale.id}" })
    end
    [ link_to("##{sale.id}", operations_sale_path(sale), class: "text-primary font-semibold"),
      ERB::Util.html_escape(sale.sale_items.map(&:description).reject(&:blank?).join(", ").presence || "—"),
      "#{number_to_currency(sale.total)} #{sale.currency}",
      ERB::Util.html_escape(sale.appointment&.employee&.name.presence || "—"),
      content_tag(:div, safe_join(actions), class: "ops-table-actions") ]
  end

  def operations_status(status)
    { "draft" => "Borrador", "posted" => "Publicada", "cancelled" => "Cancelada",
      "scheduled" => "Programada", "completed" => "Terminada", "no_show" => "Ausente" }.fetch(status, status)
  end

  def operations_action_icon(kind, label:, path: nil, button: false, data: {}, html_class: nil)
    icon = case kind
    when :edit
      '<path opacity="0.5" d="M22 10.5V12C22 16.714 22 19.071 20.536 20.536 19.071 22 16.714 22 12 22 7.286 22 4.929 22 3.464 20.536 2 19.071 2 16.714 2 12 2 7.286 2 4.929 3.464 3.464 4.929 2 7.286 2 12 2h1.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><path d="m17.301 2.806-.649.649-5.965 5.965c-.404.404-.606.606-.78.829a7.09 7.09 0 0 0-.524.847c-.122.255-.212.526-.393 1.068l-.953 2.858a.75.75 0 0 0 .94.94l2.858-.953c.542-.181.813-.271 1.068-.393.301-.143.585-.319.847-.524.223-.174.425-.376.829-.78l5.965-5.965.649-.649a2.75 2.75 0 0 0-3.892-3.892Z" stroke="currentColor" stroke-width="1.5"/><path opacity="0.5" d="M16.652 3.455s.081 1.379 1.298 2.595c1.216 1.217 2.595 1.298 2.595 1.298M10.1 15.588 8.412 13.9" stroke="currentColor" stroke-width="1.5"/>'
    when :delete
      '<path d="M20.5 6h-17" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><path d="m18.833 8.5-.46 6.899c-.177 2.655-.265 3.982-1.13 4.792C16.378 21 15.048 21 12.387 21h-.773c-2.661 0-3.991 0-4.856-.809-.865-.81-.954-2.137-1.13-4.792L5.167 8.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><path opacity="0.5" d="m9.5 11 .5 5M14.5 11l-.5 5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><path opacity="0.5" d="M6.5 6c.056 0 .084 0 .109-.001.824-.02 1.55-.544 1.83-1.319.009-.024.018-.05.035-.103l.098-.291c.082-.249.124-.373.179-.479A2.05 2.05 0 0 1 9.845 3.02C9.962 3 10.093 3 10.355 3h3.29c.262 0 .393 0 .51.019a2.05 2.05 0 0 1 1.094.788c.055.106.097.23.179.479l.097.291c.018.053.027.08.036.103.28.775 1.006 1.298 1.83 1.319.026 0 .054.001.11.001" stroke="currentColor" stroke-width="1.5"/>'
    else
      '<path opacity="0.5" d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><circle cx="12" cy="12" r="3" stroke="currentColor" stroke-width="1.5"/>'
    end
    content = content_tag(:svg, icon.html_safe, width: 24, height: 24, viewBox: "0 0 24 24", fill: "none", xmlns: "http://www.w3.org/2000/svg", aria: { hidden: true })
    classes = [ "ops-action-icon" ]
    classes << "ops-action-icon--danger" if kind == :delete
    classes << html_class if html_class.present?
    options = { class: classes.join(" "), title: label, aria: { label: label }, data: data }
    button ? button_tag(content, type: "button", **options) : link_to(content, path, **options)
  end

  def sidebar_nav_icon(kind)
    markup = case kind
    when :agenda
      '<rect opacity="0.5" x="3" y="5" width="18" height="16" rx="3" fill="currentColor"/><path d="M8 3v4M16 3v4M3 10h18" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><path d="M8 14h.01M12 14h.01M16 14h.01M8 17.5h.01M12 17.5h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>'
    when :ventas
      '<path opacity="0.5" fill="currentColor" d="M6.25 3h11.5A1.25 1.25 0 0 1 19 4.25v16.4l-2.15-1.07-1.85 1.16-2.25-1.2-2.25 1.2-1.85-1.16L5 20.65V4.25A1.25 1.25 0 0 1 6.25 3Z"/><path d="M9 8.5h6M9 12h6M9 15.5h4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>'
    when :usuarios
      '<circle cx="12" cy="6.5" r="3.5" fill="currentColor"/><path opacity="0.5" fill="currentColor" d="M5 19.5C5 16.46 8.13 14.5 12 14.5s7 1.96 7 5c0 1.1-.9 1.75-2 1.75H7c-1.1 0-2-.65-2-1.75Z"/>'
    when :empleados
      '<circle cx="9" cy="7" r="3" fill="currentColor"/><circle opacity="0.5" cx="16.5" cy="8" r="2.4" fill="currentColor"/><path fill="currentColor" d="M3.8 19.3C4.5 16.4 6.6 14.7 9 14.7s4.5 1.7 5.2 4.6c.15.6-.3 1.2-.95 1.2H4.75c-.65 0-1.1-.6-.95-1.2Z"/><path opacity="0.5" fill="currentColor" d="M14.2 15.15c1.55-.35 3.45.25 4.45 1.9.45.75.1 1.7-.75 1.7h-2.55c-.4-1.35-1-2.55-1.15-3.6Z"/>'
    when :servicios
      '<rect opacity="0.5" x="3" y="3" width="8" height="8" rx="2" fill="currentColor"/><rect x="13" y="3" width="8" height="8" rx="2" fill="currentColor"/><rect x="3" y="13" width="8" height="8" rx="2" fill="currentColor"/><rect opacity="0.5" x="13" y="13" width="8" height="8" rx="2" fill="currentColor"/>'
    when :clientes
      '<path opacity="0.5" fill="currentColor" d="M6.5 3h11A1.5 1.5 0 0 1 19 4.5v15a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 19.5v-15A1.5 1.5 0 0 1 6.5 3Z"/><circle cx="12" cy="9" r="2.25" fill="currentColor"/><path d="M8.5 16.25c.7-1.4 2-2.15 3.5-2.15s2.8.75 3.5 2.15" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>'
    else
      '<circle cx="12" cy="12" r="2.75" fill="currentColor"/><path opacity="0.5" fill="currentColor" d="M19.7 14.15 18.1 13.5a6.7 6.7 0 0 0 0-3l1.6-.65a.75.75 0 0 0 .43-.98l-1.2-2.08a.75.75 0 0 0-.95-.33l-1.6.65a6.9 6.9 0 0 0-2.6-1.5V4.1A.75.75 0 0 0 13 3.35h-2a.75.75 0 0 0-.75.75v1.51a6.9 6.9 0 0 0-2.6 1.5l-1.6-.65a.75.75 0 0 0-.95.33L3.9 7.87a.75.75 0 0 0 .43.98l1.6.65a6.7 6.7 0 0 0 0 3l-1.6.65a.75.75 0 0 0-.43.98l1.2 2.08c.2.35.63.48.95.33l1.6-.65a6.9 6.9 0 0 0 2.6 1.5v1.51c0 .41.34.75.75.75h2a.75.75 0 0 0 .75-.75v-1.51a6.9 6.9 0 0 0 2.6-1.5l1.6.65c.32.15.75.02.95-.33l1.2-2.08a.75.75 0 0 0-.43-.98Z"/>'
    end
    content_tag(:svg, markup.html_safe, class: "shrink-0", width: 20, height: 20, viewBox: "0 0 24 24", fill: "none", xmlns: "http://www.w3.org/2000/svg", aria: { hidden: true })
  end
end
