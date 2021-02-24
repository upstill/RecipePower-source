require './lib/html_utils.rb'
require 'htmlbeautifier'
class PageRefPresenter < CollectiblePresenter

  def content
    (@object.content || '').html_safe
  end

  def trimmed_content
    @object.trimmed_content
  end

  # PageRef html content depends on whether we're in admin mode.
  # By default, html content is massaged for beauty
  # In admin mode, we also present the PageRef's raw and trimmed content
  def html_content
    trimmed_content.html_safe
  end

  def content_suggestion
    "This is the raw content after trimming with CSS selectors.".html_safe
  end
end
