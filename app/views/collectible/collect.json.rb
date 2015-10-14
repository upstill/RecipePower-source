flash[:popup] ||= "Done! #{@decorator.human_name} '#{@decorator.title.truncate(20)}' #{params[:in_collection] ? 'added to' : 'removed from'} your collection."
what = {
    done: true,
    replacements: [
        collectible_collect_icon_replacement(@decorator),
        collectible_tools_menu_replacement(@decorator)
    ]
}
if params[:in_collection]
  what[:insertions] = item_insertions(@decorator, @list) # [ collectible_masonry_item_insertion(@decorator) ]
else
  what[:replacements] += item_deleters(@decorator, @list) # collectible_masonry_item_deleter(@decorator)
end
what.merge(flash_notify).to_json
