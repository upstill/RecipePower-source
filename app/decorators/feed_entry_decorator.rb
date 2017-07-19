require "templateer.rb"
class FeedEntryDecorator < CollectibleDecorator
  include Templateer
  delegate_all

  def description
    object.summary.html_safe
  end

  def external_link
    object.url
  end

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  # Feed entries can't be modified
  def read_only
    true
  end

end
