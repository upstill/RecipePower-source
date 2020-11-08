class MercuryResultPresenter < BasePresenter
  def html_content 
    super.if_present || '[No content from Mercury]'
  end
end
