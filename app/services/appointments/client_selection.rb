# frozen_string_literal: true

module Appointments
  class ClientSelection < ApplicationService
    def self.call(actor:, client_id:, new_client: nil)
      return Client.find(client_id) if new_client.blank?

      raise Domain::ValidationError, "Elige un cliente registrado o uno nuevo" if client_id.present?
      raise Domain::Forbidden unless Ability.new(actor).can?(:create, Client)

      Client.create!(new_client.symbolize_keys.slice(:name, :phone, :email))
    end
  end
end
