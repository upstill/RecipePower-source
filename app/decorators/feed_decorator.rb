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

  def imgdata use_fallback=false
    if img = @object.imgdata
      return img
    elsif use_fallback
      # The default fallback is to use an image from the underlying site
      @object.site.imgdata(true)
    end
  end

end
