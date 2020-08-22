class MercuryResultDecorator < ModelDecorator
  delegate_all

  def title
    (results.present? && results['title'].if_present) || 'Untitled MercuryResult'
  end

  def refresh_content
    @object.results['content'] = nil
    @object.bkg_launch
    @object.bkg_land
    @object.save
  end


end
