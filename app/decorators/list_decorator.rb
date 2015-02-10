require "templateer.rb"
class ListDecorator < Draper::Decorator
  include Templateer
  delegate_all

  def sourcename
    ""
  end

  def sourcehome
    ""
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
