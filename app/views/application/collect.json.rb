flash[:popup] ||= "Done! #{@decorator.human_name} '#{@decorator.title.truncate(20)}' #{params[:oust] ? 'removed from' : 'added to'} your collection."
{
  done: true,
  replacements: [
      collect_or_tag_button_replacement(@decorator, :button_size => "small", mode: :partial),
      ([ "div.pagelet-body.users-collection ##{dom_id @decorator}"] if params[:oust])
  ].compact
}.merge(flash_notify).to_json
