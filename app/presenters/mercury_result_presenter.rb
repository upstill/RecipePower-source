class MercuryResultPresenter < BasePresenter
  def html_content variant=nil
    (@object.results.present? && @object.results['content'].if_present) || '[No content from Mercury]'
  end
end
