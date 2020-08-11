class PageRefPresenter < CollectiblePresenter
  def content
    @object.content.html_safe
  end

  def html_content variant=nil
    case variant
    when 'trimmed'
      @object.trimmed_content
    when 'massaged'
      @object.massaged_content
    else
      @object.content
    end
  end
end
