# frozen_string_literal: true

module OperationsCatalog
  extend ActiveSupport::Concern

  def index
    allowed! :read, catalog_model
    @kind = controller_name
    render "operations/catalogs/index"
  end

  def datatable
    allowed! :read, catalog_model
    columns = case catalog_model.name
    when "Client" then %w[name phone email]
    when "Service" then %w[services.name service_categories.name services.duration_minutes services.price services.active]
    else %w[name active]
    end
    search_columns = catalog_model == Client ? %w[name phone email] : [ "name" ]
    scope = catalog_model.all
    if catalog_model == Service
      scope = scope.joins(:category).includes(:category)
      search_columns = %w[services.name service_categories.name]
    end
    table_page(scope, columns: columns, search_columns: search_columns) do |record|
      helpers.operations_catalog_row(record)
    end
  end

  private

  def catalog_model
    { "clients" => Client, "services" => Service, "employees" => Employee }.fetch(controller_name)
  end
end
