# app/models/concerns/datatable_searchable.rb
module DatatableSearchable
  extend ActiveSupport::Concern

  included do
    class_attribute :datatable_config
  end

  class_methods do
    def configure_datatable
      base_config = {
        searchable: [],
        sortable: [],
        includes: [],
        selects: [],
        filters: {},
        actions_partial: 'shared/datatable_actions'
      }

      yield(base_config)

      self.datatable_config = base_config
    end

    def datatable(params)
      scope = initial_scope
      joins = datatable_joins
      base_query = joins.any? ? scope.left_outer_joins(*joins) : scope
      filtered_query = apply_filters(base_query, params)
      searched_query = apply_search(filtered_query, params)
      ordered_query = apply_sorting(searched_query, params)

      {
        draw: params[:draw].to_i,
        recordsTotal: base_query.count("DISTINCT #{table_name}.id"),
        recordsFiltered: searched_query.count("DISTINCT #{table_name}.id"),
        data: format_data(ordered_query.offset(params[:start]).limit(params[:length]))
      }
    end

    private

    def base_selects
      ["#{table_name}.*"] + datatable_config[:selects]
    end

    def datatable_joins
      datatable_config[:includes].map do |assoc|
        reflections.key?(assoc.to_s) ? assoc.to_sym : nil
      end.compact
    end

    def initial_scope
      all.select(base_selects)
    end

    def apply_search(query, params)
      return query unless params.dig(:search, :value).present?

      term = "%#{params[:search][:value]}%"
      where_conditions = datatable_config[:searchable].map do |field|
        "#{field} ILIKE :term"
      end.join(' OR ')

      query.where(where_conditions, term: term)
    end

    def apply_filters(query, params)
      datatable_config[:filters]&.each do |filter_key, filter_config|
        param_key = "filter_#{filter_key}"
        next unless params[param_key].present?

        value = params[param_key]
        column = filter_config[:column]
        if value.is_a?(Array)
          value = value.reject(&:blank?)
          next if value.empty?
        end

        query = query.where(column => value)
      end

      query
    end

    def apply_sorting(query, params)
      if params[:order].present?
        order_params = params[:order].values.first
        column_index = order_params[:column].to_i
        direction = order_params[:dir].to_s.downcase

        order_column = datatable_config[:sortable][column_index]
        if column_index >= 0 && order_column.present? && %w[asc desc].include?(direction)
          return query.order(order_column => direction)
        end
      end

      query.order(created_at: :desc)
    end

    def format_data(records)
      partial = datatable_config[:actions_partial] || 'shared/datatable_actions'

      records.map do |record|
        datatable_config[:selects].each_with_object({}) do |select, hash|
          key = select.split(/ AS /i).last.split('.').last.underscore.to_sym
          hash[key] = record.read_attribute(key)
        end.merge(
          actions: ApplicationController.render(
            partial: partial,
            locals: { record: record }
          )
        )
      end
    end
  end
end
