(
response_service.dialog? ?
    { dlog: render_item(:modal) } :
    { replacements: [ item_replacement(:page) ] }
).merge(flash_notify).compact.to_json
