class MercuryResultPresenter < BasePresenter
  def html_content
    (@object.results.present? && @object.results['content'].if_present) || '[No content from Mercury]'
  end
end