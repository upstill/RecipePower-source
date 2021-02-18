class GleaningPresenter < BasePresenter

  def content_preface
    recipe_content_buttons(@object) + content_suggestion
  end
  
  def html_content
    @object.content.html_safe if @object.content.present?
  end

  def content_suggestion
    (@object.content.present? ?
        'This is the content that has been extracted from the page.' :
        'Nothing has been extracted from the page.').html_safe + 
    " To specify how to extract content using CSS, click #{edit_trimmers_button @object, 'here'}.".html_safe
  end

  # When a Gleaning is updated, what types of item get replaced?
  def update_items
    [ :content ]
  end
end
