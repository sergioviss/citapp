module DatatableHelper
  def render_datatable_filters(model)
    config = model.datatable_config
    return unless config[:filters]
  
    content_tag :div, class: "flex flex-wrap gap-4 ml-3 mb-4" do
      html = ""
      config[:filters].each do |key, opts|
        collection = opts[:collection]
        collection = collection.call if collection.respond_to?(:call)
        collection ||= default_filter_collection(model, key, opts[:column])
        html << render_filter_select(key, collection, opts)
      end
      html.html_safe
    end
  end
  
  
    private
  
    def render_filter_select(field, collection, opts = {})
    label_text = opts[:label] || field.to_s.humanize
    select_id = "filter_#{field}"
    select_name = opts[:multiple] ? "#{field}[]" : field
  
    content_tag :div, class: "flex flex-col w-64" do
      label_tag(select_id, label_text, class: "text-sm font-medium mb-1") +
      select_tag(
        select_name,
        options_for_select(collection),
        include_blank: !opts[:multiple],
        multiple: opts[:multiple],
        class: "select2 rounded border-gray-300 dark:border-gray-700",
        id: select_id,
        data: { field: field }
      )
    end
  end
  
  
  
    def default_filter_collection(model, key, column)
      column_name = column.split(".").last
      model.distinct.order(column_name).limit(100).pluck(column_name)
    end
  end
  