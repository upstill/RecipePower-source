class PageRefPresenter < CollectiblePresenter
  def content
    @object.content.html_safe
  end
end