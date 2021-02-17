class GleaningPresenter < BasePresenter
  def html_content 
    @object.content.html_safe if @object.content.present?
  end

  def content_suggestion
    "This is the material gleaned directly from the page. Click #{edit_trimmers_button @object, 'here'} to capture by CSS.".html_safe
  end

  # When a Gleaning is updated, what types of item get replaced?
  def update_items
    [ :content ]
  end
end
