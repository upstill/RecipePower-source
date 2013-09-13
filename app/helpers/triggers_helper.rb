# Methods for linking user actions to javascript
require 'uri_utils'

module TriggersHelper
  
  # Trigger a modal dialog via button
	def button_to_modal(label, path, options={})
	  options[:class] ||= "btn btn-mini"
	  link_to_modal label, path, options
	end
	
	# Embed a link to javascript for running a dialog by reference to a URL
	def link_to_modal(label, path, options={})
	  # We get the dialog with a JSON request
	  if options[:data]
	    options[:data].merge! type: :JSON
    else
      options[:data] = { type: :JSON }
    end
    # The selector optionally specifies an element to replace.
    # Move it to the element's data
	  if selector = options[:selector]
  	  options.delete(:selector) 
  	  options[:data].merge! selector: selector
	  end
  	options.merge! remote: true
  	options[:class] = "dialog-run "+(options[:class] || "")
  	path = assert_query path, area: "floating", how: "modal"
  	link_to label, path, options
  end
	
	# Embed a link to javascript for running a dialog by reference to a URL
	def link_to_submit(label, path, options={})
  	link_to_function label, "RP.submit(event, '#{path}');", options
  end
  
  def link_to_redirect(label, url, options={} )
    # This requires Javascript to bind a click handler to the link
  	link_to label, "#", options.merge( id: "link_to_redirect", "data-url" => url )
  end
  
  def button_to_update(label, url, mod_time, options={} )
    # Play nice with data fields in the link: homegrown data attributes prefaced with "data-"
    options[:last_modified] = mod_time || Time.now.httpdate # Default for updating
    options[:refresh] = true # Default for updating
	  options[:class] = "btn btn-mini update-button"
    data = {}
    url += "?mod_time="+mod_time.to_s
    data_options = %w{ last_modified hold_msg msg_selector dataType type refresh contents_selector }
    options.each do |key, val| 
      key = key.to_s
      key = "data-"+key if data_options.include? key
      data[key] = val 
    end
    link_to_function label, "RP.get_content('#{url}', 'a.update-button');", data
  end
end