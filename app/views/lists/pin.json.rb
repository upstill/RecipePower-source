# If the item is being removed from the current list/collection we have to
# provide a suitable replacement (deletion item)
{
    replacements: [list_menu_item_replacement(@list, @entity, params[:styling]),
                   (list_stream_item_deleter(@list, @entity) if @deleted)].compact
}.merge(flash_notify(@list)).to_json