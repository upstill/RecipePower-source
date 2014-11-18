{
  popup: "#{@decorator.human_name} added to your collection",
  replacements: [ collect_or_edit_button_replacement(@decorator, trigger: true, mode: :modal) ]
}.to_json
