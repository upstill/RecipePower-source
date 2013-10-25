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
	                  button_to_update("Check for new entries", "collection/relist", updated_time.to_s, msg_selector: "div.updater")].join(' ').html_safe,
	                class: "updater"
	  end
	end
end
