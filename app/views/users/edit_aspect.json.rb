if presenter = present(@decorator, current_user_or_guest.id)
  repl = presenter.aspect_editor_replacement aspect
end
{
    replacements: [ repl ].compact
}.merge(flash_notify).to_json