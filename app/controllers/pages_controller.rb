class PagesController < ApplicationController

    def pages_knowledge_base
        render layout: "default", :template =>'pages/knowledge-base'
    end

    def pages_contact_us_boxed
        render layout: "auth", :template =>'pages/contact-us-boxed'
    end

    def pages_contact_us_cover
        render layout: "auth", :template =>'pages/contact-us-cover'
    end

    def pages_faq
        render layout: "default", :template =>'pages/faq'
    end

    def pages_coming_soon_boxed
        render layout: "auth", :template =>'pages/coming-soon-boxed'
    end

    def pages_coming_soon_cover
        render layout: "auth", :template =>'pages/coming-soon-cover'
    end

    def pages_error404
        render layout: "auth", :template =>'pages/error404'
    end

    def pages_error500
        render layout: "auth", :template =>'pages/error500'
    end

    def pages_error503
        render layout: "auth", :template =>'pages/error503'
    end

    def pages_maintenence
        render layout: "auth", :template =>'pages/maintenence'
    end
end
