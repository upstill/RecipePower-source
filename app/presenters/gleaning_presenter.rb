class GleaningPresenter < BasePresenter
  def html_content 
    super.if_present || '[No content gleaned]'.html_safe
  end

  # When a Gleaning is updated, what types of item get replaced?
  def update_items
    [ :content ]
  end
end
