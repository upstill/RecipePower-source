# Define response structure after editing a collectible
# Generic JSON response for updating an @decorator and replacing it wherever it might go
jsondata = { done: response_service.update_option != :preview }.merge flash_notify
unless response_service.injector?
  nukeit = (defined?(delete) && delete) || @decorator.destroyed?
  items = [:table, :masonry, :slider, :card, :homelink, :content] unless defined?(items) && items
  jsondata[:replacements] = @replacements || []
  jsondata[:replacements] += nukeit ? item_deleters(@decorator, items) : item_replacements(@decorator, items)
  jsondata[:replacements].unshift collectible_buttons_panel_replacement(@decorator) unless nukeit
end
jsondata.to_json
