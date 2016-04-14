{
    replacements: [
      gleaning_field_replacement(@entity, @finder.label, 'input')
    ]
}.merge(flash_notify).to_json