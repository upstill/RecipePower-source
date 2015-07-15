flash[:popup] ||= "Done! #{@decorator.human_name} '#{@decorator.title.truncate(20)}' #{params[:oust] ? 'removed from' : 'added to'} your collection."
what = {
    done: true,
    replacements: [
        collectible_collect_icon_replacement(@decorator)
    ]
}
if params[:oust]
  what[:replacements] += item_deleters(@decorator, @list) # collectible_masonry_item_deleter(@decorator)
else
  what[:insertions] = item_insertions(@decorator, @list) # [ collectible_masonry_item_insertion(@decorator) ]
end
what.merge(flash_notify).to_json
