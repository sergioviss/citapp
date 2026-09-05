class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user.present?

    if user.admin?
      can :manage, :all
      # Esto permite que el usuario vea/gestione jobs si usas 
      # controladores personalizados, aunque el motor de 
      # Mission Control suele ir por su cuenta.
    end
  end
end