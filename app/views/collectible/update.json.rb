# Define response structure after editing a collectible
# Generic JSON response for updating an @decorator and replacing it wherever it might go
jsondata = { done: response_service.update_option != :preview }.merge flash_notify
unless response_service.injector?
  nukeit = (defined?(delete) && delete) || @decorator.destroyed?
  # Decide on a list of items to update
  unless defined?(items) && items # If not previously defined...
    # Consult the defined presenter, but fall back on a default list
    items = (defined?(@presenter) && @presenter.respond_to?(:update_items)) ? 
                @presenter.update_items :
                [:table, :masonry, :slider, :card, :homelink, :content]
  end
  jsondata[:replacements] = @replacements || []
  jsondata[:replacements] += nukeit ? item_deleters(@decorator, items) : item_replacements(@decorator, items)
  jsondata[:replacements].unshift collectible_buttons_panel_replacement(@decorator) unless nukeit
end
jsondata.to_json
