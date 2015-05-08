# require "templateer.rb"
class UserDecorator < CollectibleDecorator
  # include Templateer
  # delegate_all

  def title
    object.handle
  end

  def sourcename
    ""
  end

  def sourcehome
    ""
  end

  def description
    object.about
  end

  def imglink
    object.image
  end

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

end
