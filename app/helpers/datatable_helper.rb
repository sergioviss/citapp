module DatatableHelper
  def render_admin_datatable_toolbar(model, export_url: nil)
    content_tag(:div, class: 'datatable-toolbar flex flex-wrap items-center justify-between gap-4 mb-4') do
      content_tag(:div, render_datatable_filters(model), class: 'flex flex-wrap items-center gap-4') +
        render_datatable_search_and_export(export_url: export_url)
    end
  end

  def render_datatable_search_and_export(export_url: nil)
    content_tag(:div, class: 'datatable-toolbar-controls flex flex-wrap items-center gap-3') do
      render_datatable_search_input + render_datatable_export_button(export_url)
    end
  end

  def render_datatable_filters(model)
    config = model.datatable_config
    return ''.html_safe unless config[:filters]

    html = ""
    config[:filters].each do |key, opts|
      collection = opts[:collection]
      collection = collection.call if collection.respond_to?(:call)
      collection ||= default_filter_collection(model, key, opts[:column])
      html << render_filter_select(key, collection, opts)
    end
    html.html_safe
  end

  private

  def render_datatable_search_input
    content_tag(:div, class: 'datatable-search-filter flex items-center gap-2') do
      label_tag(nil, 'Buscar:', class: 'datatable-search-label text-sm font-semibold whitespace-nowrap mb-0 text-[#888ea8]') +
        tag.input(
          type: 'search',
          class: 'datatable-search-input',
          autocomplete: 'off',
          placeholder: ''
        )
    end
  end

  def render_datatable_export_button(export_url)
    return ''.html_safe if export_url.blank?

    link_to(
      export_url,
      class: 'btn btn-success shadow-sm datatable-export-btn'
    ) do
      raw('<i class="fas fa-file-excel me-2"></i>Exportar a Excel')
    end
  end

  def render_filter_select(field, collection, opts = {})
    label_text = opts[:label] || field.to_s.humanize
    select_id = "filter_#{field}"
    placeholder = opts[:placeholder] || 'Todos'

    if opts[:multiple]
      return render(
        'shared/datatable_multiselect_filter',
        field: field,
        label_text: label_text,
        collection: collection,
        select_id: select_id
      )
    end

    content_tag(:div, class: 'flex items-center gap-2') do
      label_tag(select_id, "#{label_text}:", class: 'text-sm font-semibold whitespace-nowrap mb-0 text-[#888ea8]') +
        select_tag(
          field,
          options_for_select(collection),
          include_blank: placeholder,
          class: 'select2 min-w-[180px] datatable-filter-input',
          id: select_id,
          data: {
            field: field,
            placeholder: placeholder,
            clearable: opts[:clearable] ? 'true' : nil
          }.compact
        ) +
        (if opts[:clearable]
           button_tag(
             'Limpiar',
             type: 'button',
             class: 'btn btn-outline-secondary datatable-filter-clear-btn',
             data: { filter_id: select_id }
           )
         else
           ''.html_safe
         end)
    end
  end

  def default_filter_collection(model, key, column)
    column_name = column.split('.').last
    model.distinct.order(column_name).limit(100).pluck(column_name)
  end
end
