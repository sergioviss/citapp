module ApplicationHelper
  USER_AVATAR_COLORS = %w[
    #e53935 #d81b60 #8e24aa #5e35b1 #3949ab
    #1e88e5 #039be5 #00897b #43a047 #fb8c00
    #f4511e #6d4c41
  ].freeze

  def user_display_initial(user)
    source = user&.full_name.presence || user&.email.to_s
    letter = source.to_s.strip[0]
    letter.present? ? letter.upcase : "?"
  end

  def user_avatar_color(user)
    source = user&.full_name.presence || user&.email.to_s
    USER_AVATAR_COLORS[source.to_s.each_byte.sum % USER_AVATAR_COLORS.size]
  end

  def user_initial_avatar(user, size: 36)
    text_size = size >= 40 ? "text-base" : "text-sm"
    content_tag(
      :span,
      user_display_initial(user),
      class: "inline-flex items-center justify-center shrink-0 rounded-full #{text_size} font-semibold leading-none text-white select-none",
      style: "width: #{size}px; height: #{size}px; background-color: #{user_avatar_color(user)};",
      aria: { hidden: true }
    )
  end
end
