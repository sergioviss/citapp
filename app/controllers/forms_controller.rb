class FormsController < ApplicationController
    def forms_basic
        render layout: "default", :template => 'forms/basic'
    end

    def forms_input_group
        render layout: "default", :template => 'forms/input-group'
    end

    def forms_layouts
        render layout: "default", :template => 'forms/layouts'
    end

    def forms_validation
        render layout: "default", :template => 'forms/validation'
    end

    def forms_input_mask
        render layout: "default", :template => 'forms/input-mask'
    end

    def forms_checkbox_radio
        render layout: "default", :template => 'forms/checkbox-radio'
    end

    def forms_select2
        render layout: "default", :template => 'forms/select2'
    end

    def forms_switches
        render layout: "default", :template => 'forms/switches'
    end

    def forms_wizards
        render layout: "default", :template => 'forms/wizards'
    end

    def forms_file_upload
        render layout: "default", :template => 'forms/file-upload'
    end

    def forms_quill_editor
        render layout: "default", :template => 'forms/quill-editor'
    end

    def forms_markdown_editor
        render layout: "default", :template => 'forms/markdown-editor'
    end

    def forms_date_picker
        render layout: "default", :template => 'forms/date-picker'
    end

    def forms_clipboard
        render layout: "default", :template => 'forms/clipboard'
    end

    def forms_touchspin
        render layout: "default", :template => 'forms/touchspin'
    end
end
