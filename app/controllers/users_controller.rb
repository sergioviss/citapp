class UsersController < ApplicationController
  include ExportController
  include DatatableResponder

  before_action :set_user, only: %i[show edit update destroy]

  # GET /users
  def index
    @users = User.all
    render layout: "default"
  end
  def datatable
    datatable_response
  end

  # GET /users/1
  def show
    @title = "Detalles"
    @roles = Rol.all
    render layout: "default", :template => 'users/new'
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
    render layout: "default", :template => 'users/new'
  end

  # POST /users
  def create
    @user = User.new(user_params)
    @roles = Rol.all
    @title = "Registrar"
    if @user.save
      redirect_to @user, notice: 'User was successfully created.'
    else
      render layout: "default", :template => 'users/new', status: :unprocessable_entity
    end
  end

  # PATCH/PUT /users/1
  def update
    @roles = Rol.all
    @title = "Editar"
    if @user.update(user_params)
      redirect_to @user, notice: 'User was successfully updated.', status: :see_other
    else
        render layout: "default", :template => 'users/new', status: :unprocessable_entity
    end
  end

  # DELETE /users/1
  def destroy
    @user.destroy
    redirect_to users_url, notice: 'User was successfully destroyed.', status: :see_other
  end

  def users_profile
    render layout: "default", :template =>'users/profile'
  end

  def users_account_settings
    render layout: "default", :template =>'users/user-account-settings'
  end 

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = User.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :full_name, :rol_id)
  end

end
