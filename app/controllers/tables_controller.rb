class TablesController < ApplicationController
    def tables
        render layout: "default", :template => 'tables'
    end

    def datatables_advanced
        render layout: "default", :template => 'datatables/advanced'
    end

    def datatables_alt_pagination
        render layout: "default", :template => 'datatables/alt-pagination'
    end

    def datatables_basic
        render layout: "default", :template => 'datatables/basic'
    end

    def datatables_checkbox
        render layout: "default", :template => 'datatables/checkbox'
    end

    def datatables_clone_header
        render layout: "default", :template => 'datatables/clone-header'
    end

    def datatables_column_chooser
        render layout: "default", :template => 'datatables/column-chooser'
    end

    def datatables_export
        render layout: "default", :template => 'datatables/export'
    end

    def datatables_skin
        render layout: "default", :template => 'datatables/skin'
    end

    def datatables_multi_column
        render layout: "default", :template => 'datatables/multi-column'
    end

    def datatables_multiple_tables
        render layout: "default", :template => 'datatables/multiple-tables'
    end

    def datatables_order_sorting
        render layout: "default", :template => 'datatables/order-sorting'
    end

    def datatables_range_search
        render layout: "default", :template => 'datatables/range-search'
    end

    def datatables_sticky_header
        render layout: "default", :template => 'datatables/sticky-header'
    end
end
