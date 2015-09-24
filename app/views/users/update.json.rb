repl = nil
case @updated.to_sym
  when :fullname
    selector = "ul.media-list##{dom_id response_service.user}" # Replace the whole panel
    partial = "show"
  else
    if presenter = present(@decorator, current_user_or_guest)
      repl = presenter.card_aspect_replacement @updated.to_sym
    end
end
{
    replacements: [ repl ].compact
}.merge(flash_notify).to_json
