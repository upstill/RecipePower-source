(
response_service.dialog? ?
    { dlog: render_item(:modal, viewparams: viewparams) } :
    { replacements: [ item_replacement(@entity, viewparams: viewparams) ] }
).merge(push_state).merge(flash_notify).compact.to_json
