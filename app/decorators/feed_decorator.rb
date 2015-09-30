class FeedDecorator < CollectibleDecorator

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  def typename
    (name = object.feedtypename) == :Misc ? nil : name.downcase
  end

  def imgdata
    (img = @object.imgdata).present? ? img : @object.site.imgdata
  end

end
