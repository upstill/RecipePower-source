flash[:alert] = express_resource_errors(@list) unless @list.errors.empty?
# If the item is being removed from the current list/collection we have to
# provide a suitable replacement (deletion item)
deletion = @deleted ? list_stream_item_deleter(@list, @entity) : nil
{
    replacements: [ list_menu_item_replacement(@list, @entity, params[:styling]),
                    deletion ].compact
}.merge(flash_notify).to_json