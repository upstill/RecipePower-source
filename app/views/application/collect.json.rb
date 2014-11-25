flash[:popup] ||= "#{@decorator.human_name} added to your collection"
{
  replacements: [ collect_or_edit_button_replacement(@decorator, :button_size => "small", mode: :modal) ]
}.merge(flash_notify).to_json
