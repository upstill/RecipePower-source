class MercuryResultDecorator < ModelDecorator
  delegate_all

  def title
    (results.present? && results['title'].if_present) || 'Untitled MercuryResult'
  end

end