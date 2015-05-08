# Define response structure after editing a collectible
# Generic JSON response for updating an @decorator and replacing it wherever it might go
jsondata = { done: true }.merge flash_notify
unless response_service.injector?
  nukeit = (defined?(delete) && delete) || @decorator.destroyed?
  jsondata[:replacements] = (nukeit ? item_deleters(@decorator) : item_replacements(@decorator))
  jsondata[:replacements] << collectible_buttons_panel_replacement(@decorator) unless nukeit
  # jsondata[:followup] = collectible_pagelet_followup(@decorator, nukeit)
end
jsondata.to_json
