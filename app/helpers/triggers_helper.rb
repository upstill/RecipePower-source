# Methods for linking user actions to javascript
require 'uri_utils'

module TriggersHelper
  
  # Trigger a modal dialog via button
	def button_to_modal(label, path, options={})
	  options[:class] ||= "btn btn-default btn-xs"
	  link_to_modal label, path, options
	end
	
	# Embed a link to javascript for running a dialog by reference to a URL
	def link_to_modal(label, path_or_object, options={})
    path = url_for(path_or_object)
	  # We get the dialog with a JSON request
	  if options[:data]
	    options[:data].merge! type: "json"
    else
      options[:data] = { type: "json" }
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

  # Generate a hashtag which triggers a modal dialog
  def hash_to_modal url, base_url=nil
    base_url ||= collection_url
    uri = URI.parse(url)
    index = url.index uri.path
    relative_url = assert_query(url[index..-1], :how => :modal)
    "#{base_url}#dialog:#{CGI::escape relative_url}"
  end

  def link_to_show object, label, options={}
    button_to "Show", object, remote: true, :method => :get, form: { "data-type" => "json", class: "dialog-run" }
  end
	
	# Hit a URL, with options for confirmation (:confirm-msg) and waiting (:wait-msg)
	def link_to_submit(label, path, options={})
	  options[:remote] = true
  	options[:class] = "submit "+(options[:class] || "")
  	options[:data] = { :method => options[:method] } if options[:method]
	  button_to label, path, options
  	# link_to_function label, "RP.submit(event, '#{path}');", options
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

  def defer_trigger str
    if str
      session[:trigger] = str
    else
      session.delete[:trigger]
    end
  end

  def deferred_trigger forget=false
    if str = session[:trigger]
      session.delete(:trigger) if forget
      str
    end
  end

end
