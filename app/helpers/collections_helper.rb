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
  def collection_header
    @browser.selected.handle(true) +
    if (nfound = @seeker.result_ids.count) > 0
      " (#{nfound} found)"
    else
      ""
    end
  end

  def collection_selection node, label=nil, id=nil
    label ||= node.handle
    id ||= node.css_id
    link_to label, "#", class: "collection_selection", id: id
  end

  # Declare the dropdown for a particular class of collection
  def collection_dropdown which
    menu_items = @browser.node_list(which).collect { |node|
      collection_selection node
    } << %q{<hr style="margin:5px">}
    active = @browser.selected.classed_as == which
    case which
      when :personal  # Add "All My Cookmarks", "Recently Viewed" and "New Collection..." items
        menu_css_id = "RcpBrowserCompositeUser"
        # menu_items << collection_selection( @browser.find_by_id menu_css_id)
        menu_items << collection_selection( @browser.find_by_id "RcpBrowserElementRecent"  )
        menu_items << link_to_modal( "New Personal Collection...", @browser.find_by_id("RcpBrowserCompositeUser").add_path )
        menu_items << link_to_modal( "New Personal List...", "/lists/new?modal=true" )
      when :friends  # Add "All Friends' Cookmarks" and "Make a Friend..." items
        menu_css_id = "RcpBrowserCompositeFriends"
        # menu_items << collection_selection( @browser.find_by_id menu_css_id )
        menu_items << link_to("Make a Friend...", @browser.find_by_id("RcpBrowserCompositeFriends").add_path)
      when :public   # Add "The Master Collection", and "Another Collection..." item
        menu_css_id = "RcpBrowserElementAllRecipes"
        # menu_items << collection_selection( @browser.find_by_id menu_css_id )
        menu_items << collection_selection( @browser.find_by_id "RcpBrowserCompositeChannels" )
        menu_items << link_to("Another Public Collection...", @browser.find_by_id("RcpBrowserCompositeChannels").add_path)
    end
    menu_list = "<li>" + menu_items.join('</li><li>') + "</li>"
    menu_label = %Q{#{which.to_s.capitalize}<span class="caret"><span>}.html_safe
    content_tag :li,
      # link_to( menu_label, "#", class: "dropdown-toggle", data: {toggle: "dropdown"} )+
      collection_selection(nil, menu_label, menu_css_id )+
      content_tag(:ul, menu_list.html_safe, class: "dropdown-menu"),
      class: "dropdown"+(active ? " active" : "")
  end
end
