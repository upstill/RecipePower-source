# If the item is being removed from the current list/collection we have to
# provide a suitable replacement (deletion item)
hsh = {
    replacements: [list_menu_item_replacement(@list, @entity, params[:styling]),
                   (list_stream_item_deleter(@list, @entity) if @deleted)].compact
}.merge(flash_notify(@list))
h2 = { replacements: hsh[:replacements].collect { |hr| [ hr[0].encode("ASCII-8BIT"), hr[1].encode("ASCII-8BIT") ] }
}
json1 = hsh.to_json
str = json1.gsub(/\\u([0-9a-z]{4})/) {|s| [$1.to_i(16)].pack("U")}
logger.debug "JSON response is (Unicode)"+ str
logger.debug "JSON response is (AsciI)"+ str.encode("ASCII-8BIT")
str
