flash[:popup] ||= "Done! #{@decorator.human_name} '#{@decorator.title.truncate(20)}' #{params[:oust] ? 'removed from' : 'added to'} your collection."
{
  done: true,
  replacements: [
      collectible_buttons_panel_replacement(@decorator),
      ([ "div.stream-body.users-collection ##{dom_id @decorator}"] if params[:oust])
  ].compact
}.merge(flash_notify).to_json
