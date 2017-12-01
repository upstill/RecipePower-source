{
    replacements: [
        (([:table, :card, :masonry, :slider].include? @what) ?
            item_replacement(@decorator, @what) :
            gleaning_field_replacement(@decorator, @what, @gleaning))
    ]
}.merge(flash_notify).to_json
