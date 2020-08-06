class PageRefPresenter < CollectiblePresenter
  def content
    @object.content.html_safe
  end

  def html_content
    @object.content
  end
end