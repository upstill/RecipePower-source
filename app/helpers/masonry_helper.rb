module MasonryHelper

  # Masonry items (the DOM element) are wrapped in another div for manipulating the masonry collection
=begin

  def masonry_container_class
    "js-masonry"
  end

  def masonry_wrapper_class
    "masonry-item"
  end

  def masonry_item_class
    "masonry-item-contents"
  end

  def wrap_masonry_item item, decorator
    # Wrap the item in another layer so that the item can be replaced w/o disrupting Masonry
    content_tag :div, item, class: "#{masonry_wrapper_class} stream-item #{dom_id decorator}"
  end

  # Provide a selector that finds a specific masonry item in a specific masonry list (given by entity_or_string)
  def masonry_item_selector decorator, entity_or_string=nil
    item_id = dom_id decorator
    "#{masonry_container_selector entity_or_string} div.#{masonry_item_class}##{item_id}"
  end

  def masonry_container_selector entity_or_string=nil
    entity_or_string ||= current_user_or_guest
    masonry_id = entity_or_string.is_a?(String) ? entity_or_string : "#{dom_id entity_or_string}_contents"
    masonry_id = "div#"+masonry_id unless masonry_id.blank?  # Prepend the id selector
    "#{masonry_id} div.#{masonry_container_class}"
  end

  # Provide a selector that finds the wrapper for a specific masonry item (given by entity_or_string)
  def masonry_wrapper_selector decorator, entity_or_string=nil
    item_id = dom_id decorator
    "#{masonry_container_selector entity_or_string} div.#{masonry_wrapper_class}.#{item_id}"
  end
=end

end