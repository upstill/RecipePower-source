if presenter = present(@decorator)
  repl = presenter.card_aspect_editor_replacement aspect
end
{
    replacements: [ repl ].compact
}.merge(flash_notify).to_json
