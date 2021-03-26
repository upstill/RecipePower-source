class RecipePagePresenter < CollectiblePresenter

  def content_suggestion
    return ''.html_safe unless response_service.admin_view?
    'Supposedly, this page has multiple recipes. Click the Edit button at right to demarcate them.'.html_safe
  end

  # When a Gleaning is updated, what types of item get replaced?
  def update_items
    [ :content ]
  end
end
