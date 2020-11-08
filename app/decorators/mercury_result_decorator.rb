class MercuryResultDecorator < ModelDecorator
  delegate_all

  def title
    @object.title_if_ready 'Untitled MercuryResult'
  end

end
