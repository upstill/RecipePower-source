class GleaningPresenter < BasePresenter

  def html_content
    @object.content.html_safe if @object.content.present?
  end

  def content_suggestion
    return ''.html_safe unless response_service.admin_view?
    (@object.content.present? ?
        'This is the content that has been extracted from the page using CSS selectors.' :
        'Nothing has been extracted from the page.').html_safe
  end

  # When a Gleaning is updated, what types of item get replaced?
  def update_items
    [ :content ]
  end
end
