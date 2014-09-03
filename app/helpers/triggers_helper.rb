# Methods for linking user actions to javascript
require 'uri_utils'

module TriggersHelper

  def link_to_show object, label, options={}
    button_to "Show", object, remote: true, :method => :get, form: { "data-type" => "json", class: "dialog-run" }
  end

  def link_to_redirect(label, url, options={} )
    # This requires Javascript to bind a click handler to the link
  	link_to label, "#", options.merge( id: "link_to_redirect", "data-url" => url )
  end
  
  def button_to_update(label, url, mod_time, data={} )
    # Play nice with data fields in the link: homegrown data attributes prefaced with "data-"
    data[:last_modified] = mod_time || Time.now.httpdate # Default for updating
    data[:refresh] = true # Default for updating
	  url = assert_query url, mod_time: mod_time.to_s
    options = data.slice! :last_modified, :wait_msg, :msg_selector, :dataType, :type, :refresh, :contents_selector
    options[:data] = data
    button_to_submit label, url, options
  end

  # If there's a deferred request that can be expressed as a trigger, do so, by inserting a trigger link      .
  # THIS INCLUDES DIALOG REQUESTS EMBEDDED IN THE URL
  def trigger_pending_modal delete_after=true
    if trigger = response_service.pending_modal_trigger
      link_to_modal "", trigger, class: "trigger"
    end
  end

end
