class GleaningPresenter < BasePresenter
  def html_content 
    super.if_present || '[No content gleaned]'.html_safe
  end
end
