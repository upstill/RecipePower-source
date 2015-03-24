# If the item is being removed from the current list/collection we have to
# provide a suitable replacement (deletion item)
# TODO: Port this to ItemHelper
hsh = {
    replacements: [list_menu_item_replacement(@list, @entity, params[:styling]),
                   (item_deleters(@entity, @list) if @deleted)].compact
}.merge(flash_notify(@list))
json1 = hsh.to_json
str = json1.gsub(/\\u([0-9a-z]{4})/) {|s| [$1.to_i(16)].pack("U")}
logger.debug "JSON response in #{str.encoding}: "+ str
str
