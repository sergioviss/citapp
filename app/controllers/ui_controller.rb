class UiController < ApplicationController
    def components_tabs
        render layout: "default", :template => 'components/tabs'
    end

    def components_accordions
        render layout: "default", :template => 'components/accordions'
    end

    def components_modals
        render layout: "default", :template => 'components/modals'
    end

    def components_cards
        render layout: "default", :template => 'components/cards'
    end

    def components_carousel
        render layout: "default", :template => 'components/carousel'
    end

    def components_countdown
        render layout: "default", :template => 'components/countdown'
    end

    def components_counter
        render layout: "default", :template => 'components/counter'
    end

    def components_sweet_alert
        render layout: "default", :template => 'components/sweetalert'
    end

    def components_timeline
        render layout: "default", :template => 'components/timeline'
    end

    def components_notifications
        render layout: "default", :template => 'components/notifications'
    end

    def components_media_object
        render layout: "default", :template => 'components/media-object'
    end

    def components_list_group
        render layout: "default", :template => 'components/list-group'
    end

    def components_pricing
        render layout: "default", :template => 'components/pricing-table'
    end

    def components_lightbox
        render layout: "default", :template => 'components/lightbox'
    end

    def elements_alerts
        render layout: "default", :template => 'elements/alerts'
    end

    def elements_avatar
        render layout: "default", :template => 'elements/avatar'
    end

    def elements_badges
        render layout: "default", :template => 'elements/badges'
    end

    def elements_breadcrumbs
        render layout: "default", :template => 'elements/breadcrumbs'
    end

    def elements_buttons
        render layout: "default", :template => 'elements/buttons'
    end

    def elements_buttons_group
        render layout: "default", :template => 'elements/buttons-group'
    end

    def elements_color_library
        render layout: "default", :template => 'elements/color-library'
    end

    def elements_dropdown
        render layout: "default", :template => 'elements/dropdown'
    end

    def elements_infobox
        render layout: "default", :template => 'elements/infobox'
    end

    def elements_jumbotron
        render layout: "default", :template => 'elements/jumbotron'
    end

    def elements_loader
        render layout: "default", :template => 'elements/loader'
    end

    def elements_pagination
        render layout: "default", :template => 'elements/pagination'
    end

    def elements_popovers
        render layout: "default", :template => 'elements/popovers'
    end

    def elements_progress_bar
        render layout: "default", :template => 'elements/progress-bar'
    end

    def elements_search
        render layout: "default", :template => 'elements/search'
    end

    def elements_tooltips
        render layout: "default", :template => 'elements/tooltips'
    end

    def elements_treeview
        render layout: "default", :template => 'elements/treeview'
    end

    def elements_typography
        render layout: "default", :template => 'elements/typography'
    end

    def charts
        render layout: "default", :template => 'charts'
    end

    def widgets
        render layout: "default", :template => 'widgets'
    end

    def font_icons
        render layout: "default", :template => 'font-icons'
    end

    def drag_and_drop
        render layout: "default", :template => 'dragndrop'
    end
end
