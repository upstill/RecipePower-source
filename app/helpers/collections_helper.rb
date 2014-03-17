module CollectionsHelper
require "time_check"
	
	def collection_itemtitle
	  ttl = @node.guide(false)
	  @node.selected ? "" : %Q{title="#{ttl}"}
  end
		
	def collection_updater
	  if updated_time = @seeker.updated_at
	    content_tag :div, 
	                ["This feed was last updated", 
	                  time_ago_in_words(updated_time), 
	                  "ago.", 
	                  button_to_update("Check for new entries", "/collection/refresh", updated_time.to_s, wait_msg: "Checking for updates...", msg_selector: "div.updater")].join(' ').html_safe,
	                class: "updater"
	  end
  end

  # The current browser entity
  def collection_name
    @browser.selected.handle
  end

  def collection_dropdown which
    menu_items = @browser.node_list(which).collect { |node|
      link_to node.handle, "#", class: "collection_selection", id: node.css_id
    }
    active = @browser.selected_is_under which
    case which
      when :personal  # Add "All My Cookmarks", "Recently Viewed" and "New Collection..." items
      when :friends  # Add "All Friends' Recipes" and "Make a Friend..." items
      when :public   # Add "Another Collection..." item
    end
    menu_list = "<li>" + menu_items.join('</li><li>') + "</li>"
    content_tag :li,
      link_to( %Q{#{which.to_s.capitalize}<span class="caret"><span>}.html_safe, "#", class: "dropdown-toggle", data: {toggle: "dropdown"} )+
      content_tag(:ul, menu_list.html_safe, class: "dropdown-menu"),
      class: "dropdown"+(active ? " active" : "")
  end
end
