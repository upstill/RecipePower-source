# Define response structure after editing a collectible
# Generic JSON response for updating an @decorator and replacing it wherever it might go
jsondata = { done: true }.merge(flash_notify)
unless response_service.injector?
  nukeit = (defined?(delete) && delete) || @decorator.destroyed?
  jsondata[:replacements] = [
      (collectible_buttons_panel_replacement(@decorator) unless nukeit),
      (nukeit ? collectible_masonry_item_deleter(@decorator) : collectible_masonry_item_replacement(@decorator)),
      collectible_table_row_replacement(@decorator, nukeit)
  ].compact
  jsondata[:followup] = collectible_pagelet_followup(@decorator, nukeit)
end
jsondata.to_json
