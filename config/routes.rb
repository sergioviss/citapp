Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "login", to: "sessions#create"
      delete "logout", to: "sessions#destroy"
    end
  end

 
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  # Defines the root path route ("/")
  root 'dashboard#index'

  namespace :admin do
    resources :users, only: %i[edit update]
  end

  devise_for :users, skip: [:registrations], controllers: {
    sessions: "users/sessions",
    passwords: "users/passwords"
  }
  as :user do
    get 'users/edit' => 'users/registrations#edit', :as => 'edit_user_registration'
    put 'users' => 'devise/registrations#update', :as => 'user_registration'
  end
  resources :users do
    collection do
      get 'datatable'
      get 'export', defaults: { format: 'xlsx' }
    end
  end

  authenticate :user, ->(u) { u.admin? } do
    mount MissionControl::Jobs::Engine => "/jobs"
  end

  # Dashboard
  get '/analytics', to: 'dashboard#analytics'
  get '/finance', to: 'dashboard#finance'
  get '/crypto', to: 'dashboard#crypto'
  
  
  get '/apps/chat', to: 'apps#chat'
  get '/apps/mailbox', to: 'apps#mailbox'
  get '/apps/todolist', to: 'apps#todolist'
  get '/apps/notes', to: 'apps#notes'
  get '/apps/contacts', to: 'apps#contacts'
  get '/apps/calendar', to: 'apps#calendar'
  get '/apps/scrumboard', to: 'apps#scrumboard'
  get '/apps/invoice/add', to: 'apps#invoice_add'
  get '/apps/invoice/edit', to: 'apps#invoice_edit'
  get '/apps/invoice/list', to: 'apps#invoice_list'
  get '/apps/invoice/preview', to: 'apps#invoice_preview'
  
  get '/components/tabs', to: 'ui#components_tabs'
  get '/components/accordions', to: 'ui#components_accordions'
  get '/components/modals', to: 'ui#components_modals'
  get '/components/cards', to: 'ui#components_cards'
  get '/components/carousel', to: 'ui#components_carousel'
  get '/components/countdown', to: 'ui#components_countdown'
  get '/components/counter', to: 'ui#components_counter'
  get '/components/sweetalert', to: 'ui#components_sweet_alert'
  get '/components/timeline', to: 'ui#components_timeline'
  get '/components/notifications', to: 'ui#components_notifications'
  get '/components/media-object', to: 'ui#components_media_object'
  get '/components/list-group', to: 'ui#components_list_group'
  get '/components/pricing-table', to: 'ui#components_pricing'
  get '/components/lightbox', to: 'ui#components_lightbox'
  
  get '/elements/alerts', to: 'ui#elements_alerts'
  get '/elements/avatar', to: 'ui#elements_avatar'
  get '/elements/badges', to: 'ui#elements_badges'
  get '/elements/breadcrumbs', to: 'ui#elements_breadcrumbs'
  get '/elements/buttons', to: 'ui#elements_buttons'
  get '/elements/buttons-group', to: 'ui#elements_buttons_group'
  get '/elements/color-library', to: 'ui#elements_color_library'
  get '/elements/dropdown', to: 'ui#elements_dropdown'
  get '/elements/infobox', to: 'ui#elements_infobox'
  get '/elements/jumbotron', to: 'ui#elements_jumbotron'
  get '/elements/loader', to: 'ui#elements_loader'
  get '/elements/pagination', to: 'ui#elements_pagination'
  get '/elements/popovers', to: 'ui#elements_popovers'
  get '/elements/progress-bar', to: 'ui#elements_progress_bar'
  get '/elements/search', to: 'ui#elements_search'
  get '/elements/tooltips', to: 'ui#elements_tooltips'
  get '/elements/treeview', to: 'ui#elements_treeview'
  get '/elements/typography', to: 'ui#elements_typography'
  
  get '/charts', to: 'ui#charts'
  get '/widgets', to: 'ui#widgets'
  get '/font-icons', to: 'ui#font_icons'
  get '/dragndrop', to: 'ui#drag_and_drop'

  get '/datatables/advanced', to: 'tables#datatables_advanced'
  get '/datatables/basic', to: 'tables#datatables_basic'
  get '/datatables/sticky-header', to: 'tables#datatables_sticky_header'
  get '/datatables/order-sorting', to: 'tables#datatables_order_sorting'
  get '/datatables/multi-column', to: 'tables#datatables_multi_column'
  get '/datatables/multiple-tables', to: 'tables#datatables_multiple_tables'
  get '/datatables/alt-pagination', to: 'tables#datatables_alt_pagination'
  get '/datatables/checkbox', to: 'tables#datatables_checkbox'
  get '/datatables/clone-header', to: 'tables#datatables_clone_header'
  get '/datatables/column-chooser', to: 'tables#datatables_column_chooser'
  get '/datatables/range-search', to: 'tables#datatables_range_search'
  get '/datatables/export', to: 'tables#datatables_export'
  get '/datatables/skin', to: 'tables#datatables_skin'
  get '/tables', to: 'tables#tables'
  
  get '/forms/basic', to: 'forms#forms_basic'
  get '/forms/input-group', to: 'forms#forms_input_group'
  get '/forms/layouts', to: 'forms#forms_layouts'
  get '/forms/validation', to: 'forms#forms_validation'
  get '/forms/input-mask', to: 'forms#forms_input_mask'
  get '/forms/select2', to: 'forms#forms_select2'
  get '/forms/touchspin', to: 'forms#forms_touchspin'
  get '/forms/checkbox-radio', to: 'forms#forms_checkbox_radio'
  get '/forms/switches', to: 'forms#forms_switches'
  get '/forms/wizards', to: 'forms#forms_wizards'
  get '/forms/file-upload', to: 'forms#forms_file_upload'
  get '/forms/quill-editor', to: 'forms#forms_quill_editor'
  get '/forms/markdown-editor', to: 'forms#forms_markdown_editor'
  get '/forms/date-picker', to: 'forms#forms_date_picker'
  get '/forms/clipboard', to: 'forms#forms_clipboard'

  get '/pages/knowledge-base', to: 'pages#pages_knowledge_base'
  get '/pages/faq', to: 'pages#pages_faq'
  get '/pages/contact-us-boxed', to: 'pages#pages_contact_us_boxed'
  get '/pages/contact-us-cover', to: 'pages#pages_contact_us_cover'
  get '/pages/coming-soon-boxed', to: 'pages#pages_coming_soon_boxed'
  get '/pages/coming-soon-cover', to: 'pages#pages_coming_soon_cover'
  get '/pages/error404', to: 'pages#pages_error404'
  get '/pages/error500', to: 'pages#pages_error500'
  get '/pages/error503', to: 'pages#pages_error503'
  get '/pages/maintenence', to: 'pages#pages_maintenence'

  get '/users/profile', to: 'users#users_profile'
  get '/users/user-account-settings', to: 'users#users_account_settings'

  get '/auth/boxed-signin', to: 'auth#auth_boxed_signin'
  get '/auth/boxed-signup', to: 'auth#auth_boxed_signup'
  get '/auth/boxed-lockscreen', to: 'auth#auth_boxed_lockscreen'
  get '/auth/boxed-password-reset', to: 'auth#auth_boxed_password_reset'
  get '/auth/cover-login', to: 'auth#auth_cover_login'
  get '/auth/cover-register', to: 'auth#auth_cover_register'
  get '/auth/cover-lockscreen', to: 'auth#auth_cover_lockscreen'
  get '/auth/cover-password-reset', to: 'auth#auth_cover_password_reset'

  # Template Customizer - guarda configuración de tema en config/theme.yml
  patch '/theme/update', to: 'theme#update', as: :theme_update

  
end
