# frozen_string_literal: true

admin_role = Role.find_or_initialize_by(code: "admin")
admin_role.name = "Administrador"
admin_role.save!

receptionist_role = Role.find_or_initialize_by(code: "receptionist")
receptionist_role.name = "Recepcionista"
receptionist_role.save!

employee_role = Role.find_or_initialize_by(code: "employee")
employee_role.name = "Empleado"
employee_role.save!

ApplicationRecord.transaction do
  BusinessSetting.find_or_create_by!(id: 1) do |settings|
    settings.name = ENV.fetch("BUSINESS_NAME", "Citapp")
    settings.time_zone = ENV.fetch("BUSINESS_TIME_ZONE", "America/Hermosillo")
    settings.currency = ENV.fetch("BUSINESS_CURRENCY", "MXN")
  end

  # Provision only an explicitly requested new account. Re-running seeds must
  # never reactivate, promote or reset an existing user's credentials.
  email = ENV["ADMIN_EMAIL"].to_s.strip.downcase
  if email.present? && !User.exists?(email: email)
    password = ENV["ADMIN_PASSWORD"]
    raise "Define ADMIN_PASSWORD para crear el administrador" if password.blank?

    User.create!(email: email, full_name: ENV.fetch("ADMIN_NAME", "Administrador"),
      role: admin_role, password: password, password_confirmation: password)
  end
end

# Datos ficticios para recorrer la interfaz local. Son opcionales para no
# contaminar bases reales y se pueden ejecutar más de una vez sin duplicarse.
if ENV["SEED_DEMO_DATA"] == "true"
  raise "Los datos demo solo se permiten en desarrollo o pruebas" if Rails.env.production?

  actor = User.active.includes(:role, :employee).order(:id).detect do |user|
    ability = Ability.new(user)
    ability.can?(:create, Appointment) && ability.can?(:create, Sale)
  end
  raise "Crea una cuenta activa de administrador o recepción antes de cargar datos demo" unless actor

  settings = BusinessSetting.current!
  zone = Time.find_zone!(settings.time_zone)

  ApplicationRecord.transaction do
    clients = [
      [ "Ana López", "+52 662 123 4567", "ana.lopez@example.test" ],
      [ "Carlos Mendoza", "+52 662 234 5678", "carlos.mendoza@example.test" ],
      [ "María Torres", "+52 662 345 6789", "maria.torres@example.test" ],
      [ "Sofía Ramírez", "+52 662 456 7890", "sofia.ramirez@example.test" ],
      [ "Diego Hernández", "+52 662 567 8901", "diego.hernandez@example.test" ]
    ].to_h do |name, phone, email|
      client = Client.find_or_initialize_by(email: email)
      client.assign_attributes(name: name, phone: phone)
      client.save!
      [ name, client ]
    end

    services = [
      [ "Corte de cabello", 30, 250 ],
      [ "Corte y peinado", 60, 480 ],
      [ "Manicure", 45, 300 ],
      [ "Pedicure", 60, 420 ],
      [ "Masaje relajante", 60, 600 ]
    ].to_h do |name, duration, price|
      service = Service.find_or_initialize_by(name: name)
      service.assign_attributes(duration_minutes: duration, price: price, active: true)
      service.save!
      [ name, service ]
    end

    employees = [ "Ana García", "Carlos Ruiz", "María Torres" ].to_h do |name|
      employee = Employee.find_or_initialize_by(name: name)
      employee.active = true
      employee.save!
      services.each_value { |service| employee.employee_services.find_or_create_by!(service: service) }
      (1..7).each do |weekday|
        [ [ "09:00", "13:00" ], [ "14:00", "18:00" ] ].each do |starts_at, ends_at|
          employee.employee_working_hours.find_or_create_by!(weekday: weekday, starts_at: starts_at, ends_at: ends_at)
        end
      end
      [ name, employee ]
    end

    date = Time.current.in_time_zone(zone).to_date
    demo_appointments = [
      [ "Ana López", "Ana García", "10:00", [ "Corte de cabello" ] ],
      [ "Carlos Mendoza", "Carlos Ruiz", "11:00", [ "Corte y peinado" ] ],
      [ "María Torres", "María Torres", "15:00", [ "Manicure", "Pedicure" ] ]
    ].map do |client_name, employee_name, time, service_names|
      starts_at = zone.parse("#{date} #{time}")
      appointment = Appointment.find_by(client: clients.fetch(client_name), employee: employees.fetch(employee_name), starts_at: starts_at)
      appointment ||= Appointments::Book.call(actor: actor, client_id: clients.fetch(client_name).id,
        employee_id: employees.fetch(employee_name).id, service_ids: service_names.map { |name| services.fetch(name).id }, starts_at: starts_at)
      appointment
    end

    appointment_sale = demo_appointments.first.sale || Sales::SaveDraft.call(actor: actor,
      client_id: demo_appointments.first.client_id, appointment_id: demo_appointments.first.id,
      items: demo_appointments.first.appointment_services.map { |item| { service_id: item.service_id, appointment_service_id: item.id } })
    Sales::Publish.call(actor: actor, sale: appointment_sale) if appointment_sale.draft?

    draft = Sale.find_by(notes: "Venta demo pendiente") || Sales::SaveDraft.call(actor: actor,
      client_id: clients.fetch("Sofía Ramírez").id, notes: "Venta demo pendiente",
      items: [ { service_id: services.fetch("Masaje relajante").id, quantity: 1 } ])

    Payment.find_or_create_by!(idempotency_key: "11111111-1111-4111-8111-111111111111") do |payment|
      payment.assign_attributes(sale: appointment_sale, registered_by: actor, kind: "receipt", method: "cash",
        amount: appointment_sale.total, tendered_amount: appointment_sale.total, occurred_at: Time.current)
    end

    puts "Datos demo listos: #{clients.size} clientes, #{services.size} servicios, #{employees.size} empleados, #{demo_appointments.size} citas, 1 venta publicada y 1 borrador (venta ##{draft.id})."
  end
end
