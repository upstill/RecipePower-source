# Methods for linking user actions to javascript
require 'uri_utils'

module TriggersHelper

  def link_to_redirect(label, url, options={} )
    # This requires Javascript to bind a click handler to the link
  	link_to label, "#", options.merge( id: "link_to_redirect", "data-url" => url )
  end

  def trigger_pending_results path, options={}
    options[:class] = "#{options[:class]} hide"
    link_to_submit "", path, options.merge( :mode => :partial, trigger: true )
  end

  # If there's a deferred request that can be expressed as a trigger, do so by inserting a trigger link      .
  # THIS INCLUDES DIALOG REQUESTS EMBEDDED IN THE URL
  def trigger_pending_modal delete_after=true
    if trigger = pending_modal_trigger
      link_to_submit "", trigger, :mode => :modal, trigger: true, class: "hide"
    end
  end

  # Provide a link to a full page with a builtin trigger to a certain dialog
  def page_with_trigger page, dialog=nil
    page, dialog = nil, page if dialog.nil? # If only one argument, assume it's the dialog
    page ||= popup_url # The popup controller knows how to handle a page request for a dialog
    options = { mode: :modal }
    triggerparam = assert_query(dialog, options )
    pt = assert_query page, trigger: %Q{"#{triggerparam}"}
    pt
  end

end
