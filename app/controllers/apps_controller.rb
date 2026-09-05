class AppsController < ApplicationController
    def chat
       render layout: "default", :template => 'apps/chat'
    end
    def mailbox
        render layout: "default", :template => 'apps/mailbox'
     end
     def todolist
        render layout: "default", :template => 'apps/todolist'
     end
     def notes
        render layout: "default", :template => 'apps/notes'
     end
     def contacts
        render layout: "default", :template => 'apps/contacts'
     end
     def calendar
        render layout: "default", :template => 'apps/calendar'
     end
     def scrumboard
        render layout: "default", :template => 'apps/scrumboard'
     end
     def invoice_add
        render layout: "default", :template => 'apps/invoice/add'
     end
     def invoice_edit
        render layout: "default", :template => 'apps/invoice/edit'
     end
     def invoice_list
        render layout: "default", :template => 'apps/invoice/list'
     end
     def invoice_preview
        render layout: "default", :template => 'apps/invoice/preview'
     end
  
end
