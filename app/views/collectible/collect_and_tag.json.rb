# When adding an entity to a collection AND tagging it
{
    # insertions: [ collectible_masonry_item_insertion(@decorator) ],
    insertions: [ item_insertion(@decorator) ],
    dlog: with_format("html") { render response_service.select_render('tag') }
}.merge(push_state(:tag)).merge(flash_notify).to_json
