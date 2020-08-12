require './lib/html_utils.rb'
require 'htmlbeautifier'
class PageRefPresenter < CollectiblePresenter
  def content
    @object.content.html_safe
  end

  def massaged_content
    # Turn raw extracted HTML into something presentable to a user
    return nil if (tc = @object.trimmed_content).blank? # Protect against bad input
    nk = process_dom tc
    # massaged = html.gsub /\n(?!(p|br))/, "\n<br>"
    HtmlBeautifier.beautify nk.to_s
  end

  def html_content variant=nil
    case variant
    when 'trimmed'
      @object.trimmed_content
    when 'massaged'
      massaged_content
    else
      @object.content
    end
  end
end
