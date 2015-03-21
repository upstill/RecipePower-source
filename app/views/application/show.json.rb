(
response_service.dialog? ?
    { dlog: render_item } :
    { replacements: [ item_replacement ] }
).merge(flash_notify).compact.to_json
