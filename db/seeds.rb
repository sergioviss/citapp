# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)
rol_admin = Rol.find_or_create_by(name: 'Administrador')
soporte = User.find_by(email: 'soporte@cuatropuntocero.solutions')
if soporte.nil?
  soporte = User.new
  soporte.full_name = 'Soporte'
  soporte.email = 'soporte@cuatropuntocero.solutions'
  soporte.rol_id = rol_admin.id
  soporte.password = 'Solutions123456'
  soporte.password_confirmation = 'Solutions123456'
  soporte.save
end