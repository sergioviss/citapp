module ModalResponder
  extend ActiveSupport::Concern

  private

  def modal_form_response(title:, partial:, locals: {}, title_badge: nil, title_badge_note: nil)
    render json: {
      title: title,
      title_badge: title_badge,
      title_badge_note: title_badge_note,
      html: render_to_string(
        partial: partial,
        locals: locals.merge(modal: true),
        formats: [:html]
      )
    }
  end
end
