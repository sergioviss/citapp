class UsersController < ApplicationController
  include ExportController
  include DatatableResponder
  include ModalResponder

  before_action :require_admin!, except: %i[users_profile users_account_settings]
  before_action :set_user, only: %i[show edit update destroy]

  # GET /users
  def index
    @page_title = 'Usuarios'
    @users = User.all
    @user = User.new
    @roles = Rol.all
    @mode = 'new'
    render layout: "default"
  end
  def datatable
    datatable_response
  end

  # GET /users/1
  def show
    @title = "Detalles"
    @roles = Rol.all
    respond_to do |format|
      format.html { render layout: "default", template: 'users/new' }
      format.json do
        modal_form_response(
          title: 'Detalles de Usuario',
          partial: 'users/form',
          locals: { user: @user, form_title: 'Detalles', roles: @roles }
        )
      end
    end
  end

  # GET /users/new
  def new
    @user = User.new
    @roles = Rol.all
    @title = "Registrar"
    @mode = 'new'
    render layout: "default", :template => 'users/new'
  end

  # GET /users/1/edit
  def edit
    @roles = Rol.all
    @title = "Editar"
    respond_to do |format|
      format.html { render layout: "default", template: 'users/new' }
      format.json do
        modal_form_response(
          title: 'Editar Usuario',
          partial: 'users/form',
          locals: { user: @user, form_title: 'Editar', roles: @roles }
        )
      end
    end
  end

  # POST /users
  def create
    @user = User.new(user_params)
    @roles = Rol.all
    @title = "Registrar"
    if @user.save
      respond_to do |format|
        format.html { redirect_to @user, notice: 'Usuario creado correctamente.' }
        format.json { render json: { success: true, message: 'Usuario creado correctamente.' }, status: :created }
      end
    else
      respond_to do |format|
        format.html { render layout: "default", :template => 'users/new', status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /users/1
  def update
    @roles = Rol.all
    @title = "Editar"
    if @user.update(user_params)
      respond_to do |format|
        format.html { redirect_to @user, notice: 'Usuario actualizado correctamente.', status: :see_other }
        format.json { render json: { success: true, message: 'Usuario actualizado correctamente.' } }
      end
    else
      respond_to do |format|
        format.html { render layout: "default", template: 'users/new', status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1
  def destroy
    if @user.admin? && User.joins(:rol).where(rols: { name: 'Administrador' }).count <= 1
      redirect_to users_url, alert: 'No se puede eliminar el último administrador.'
      return
    end

    @user.destroy
    redirect_to users_url, notice: 'Usuario eliminado correctamente.', status: :see_other
  end

  def users_profile
    render layout: "default", :template =>'users/profile'
  end

  def users_account_settings
    render layout: "default", :template =>'users/user-account-settings'
  end 

  private

  def require_admin!
    return if current_user&.admin?

    redirect_to root_path, alert: 'No autorizado'
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = User.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :full_name, :rol_id)
  end

end
