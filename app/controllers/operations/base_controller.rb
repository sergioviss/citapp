# frozen_string_literal: true

module Operations
  class BaseController < ApplicationController
    layout "default"
    before_action :require_active_user!

    rescue_from Domain::Error, with: :domain_error
    rescue_from CanCan::AccessDenied do
      operation_error("No autorizado", :forbidden)
    end
    rescue_from ActiveRecord::RecordNotFound do
      operation_error("Registro no encontrado", :not_found)
    end
    rescue_from ActiveRecord::RecordInvalid do |error|
      operation_error(error.record.errors.full_messages.join(", "), :unprocessable_entity)
    end
    rescue_from ActionController::ParameterMissing, ArgumentError, KeyError do
      operation_error("Revisa los campos obligatorios y sus formatos", :unprocessable_entity)
    end
    rescue_from ActiveRecord::RecordNotUnique, ActiveRecord::InvalidForeignKey, ActiveRecord::CheckViolation do
      operation_error("Los datos entran en conflicto con un registro existente o una regla de integridad", :conflict)
    end

    private

    def require_active_user!
      raise Domain::Forbidden unless current_user&.active?
    end

    def allowed!(action, record)
      authorize! action, record
    end

    def saved(record, location: operations_root_path, status: :ok)
      respond_to do |format|
        format.html { redirect_to location, notice: "Operación guardada", status: :see_other }
        format.json { response.set_header("Location", location); render json: record, status: status }
      end
    end

    def table_page(scope, columns:, search_columns:)
      total = scope.count
      query = params.dig(:search, :value).to_s.strip.first(100)
      if query.present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        scope = scope.where(search_columns.map { |column| "#{column} ILIKE :query" }.join(" OR "), query: pattern)
      end
      filtered = scope.count
      order = params[:order]&.values&.first || {}
      column = columns[order[:column].to_i] || columns.first
      direction = order[:dir] == "desc" ? :desc : :asc
      scope = scope.reorder(column => direction).order(id: :desc)
      records = scope.offset([ params[:start].to_i, 0 ].max).limit(params[:length].to_i.clamp(1, 100))
      render json: { draw: params[:draw].to_i, recordsTotal: total, recordsFiltered: filtered,
        data: records.map { |record| yield record } }
    end

    def domain_error(error)
      status = case error
      when Domain::Forbidden then :forbidden
      when Domain::Conflict then :conflict
      else :unprocessable_entity
      end
      operation_error(error.message.presence || "No autorizado", status)
    end

    def operation_error(message, status)
      respond_to do |format|
        format.html { redirect_to operations_root_path, alert: message, status: :see_other }
        format.json { render json: { error: message }, status: status }
      end
    end
  end
end
