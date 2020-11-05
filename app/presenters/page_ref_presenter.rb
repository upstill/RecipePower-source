require './lib/html_utils.rb'
require 'htmlbeautifier'
class PageRefPresenter < CollectiblePresenter

  def content
    (@object.content || '').html_safe
  end

  def trimmed_content
    @object.trimmed_content
  end

  def massaged_content
    # Turn raw extracted HTML into something presentable to a user
    return nil if (tc = @object.trimmed_content).blank? # Protect against bad input
    nk = process_dom tc
    # massaged = html.gsub /\n(?!(p|br))/, "\n<br>"
    HtmlBeautifier.beautify nk.to_s
  end

  # PageRef html content depends on whether we're in admin mode.
  # By default, html content is massaged for beauty
  # In admin mode, we also present the PageRef's raw and trimmed content
  def html_content
    response_service.admin_view? ?
      with_format('html') { render 'content_variants', presenter: self } :
      massaged_content.html_safe
  end
end
