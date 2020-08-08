class GleaningPresenter < BasePresenter
  def html_content variant=nil
    @object.result_for('Content').if_present || '[No content gleaned]'
  end
end
