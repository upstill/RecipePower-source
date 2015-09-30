(
response_service.dialog? ?
    { dlog: render_item(:modal) } :
    { replacements: [ item_replacement ] }
).merge(push_state).merge(flash_notify).compact.to_json
