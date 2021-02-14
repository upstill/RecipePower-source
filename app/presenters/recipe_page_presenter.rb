class RecipePagePresenter < BasePresenter

  def html_content
    super.if_present || "No RecipePage content (PageRef content is#{' not' if @object.page_ref.content_ready?} empty)".html_safe
  end

  # When a Gleaning is updated, what types of item get replaced?
  def update_items
    [ :content ]
  end
end
