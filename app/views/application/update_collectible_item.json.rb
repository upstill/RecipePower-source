# Define response structure after editing a collectible
replacements = [
#     collect_or_edit_button_replacement( entity ),
     collectible_masonry_item_replacement( entity, destroyed )
    # collectible_smallpic_replacement( entity, destroyed )
]
# replacements << [
    # "."+feed_list_element_class(@feed_entry),
    # with_format("html") { render_to_string partial: "shared/feed_entry" }
# ] if @feed_entry
{
    done: true, # i.e., editing is finished, close the dialog
    popup: notice,
    title: truncate( entity.title, :length => 60),
    replacements: replacements,
    action: params[:action],
    domID: dom_id( entity ),
    processorFcn: "RP.rcp_list.update"
}.to_json
