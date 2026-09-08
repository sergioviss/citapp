ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    def password_digest
      Devise::Encryptor.digest(User, "Password1!")
    end

    def book_appointment!(actor: users(:receptionist), employee:, client:, services:, starts_at:, ends_at: nil, interpret_as_local: true)
      Appointments::Book.call(
        actor: actor,
        client_id: client.id,
        employee_id: employee.id,
        service_ids: Array(services).map(&:id),
        starts_at: starts_at,
        ends_at: ends_at,
        interpret_as_local: interpret_as_local
      )
    end

    def create_client!(name: "Cliente #{SecureRandom.hex(4)}")
      Client.create!(name: name, phone: "5550000000", email: "cliente@example.com")
    end

    def create_service!(name: "Corte", duration_minutes: 30, price: 100, active: true)
      Service.create!(name: name, duration_minutes: duration_minutes, price: price, active: active)
    end

    def create_employee!(name: "Estilista #{SecureRandom.hex(4)}", user: nil, active: true, services: [], hours: default_weekday_hours)
      employee = Employee.create!(name: name, user: user, active: active)
      Array(services).each { |service| employee.employee_services.create!(service: service) }
      hours.each do |slot|
        employee.employee_working_hours.create!(slot)
      end
      employee
    end

    def default_weekday_hours
      (1..5).map { |weekday| { weekday: weekday, starts_at: "09:00", ends_at: "18:00" } }
    end

    def local_slot(date, hour, min = 0)
      format("%s %02d:%02d", date, hour, min)
    end
  end
end
