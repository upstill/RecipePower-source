module ActionMailer
  module MailHelper
    require './lib/uri_utils.rb'
    def page_with_trigger page, dialog=nil
      page, dialog = nil, page if dialog.nil? # If only one argument, assume it's the dialog
      page ||= popup_url # The popup controller knows how to handle a page request for a dialog
      options = { mode: :modal }
      triggerparam = assert_query(dialog, options )
      pt = assert_query page, trigger: %Q{"#{triggerparam}"}
      pt
    end
  end
end