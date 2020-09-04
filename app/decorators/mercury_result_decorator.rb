class MercuryResultDecorator < ModelDecorator
  delegate_all

  def title
    @object.title_if_ready || 'Untitled MercuryResult'
  end

  def refresh_content
    @object.content_needed = true
    @object.content_ready = false
    @object.ensure_attributes :content
    @object.save
  end


end
