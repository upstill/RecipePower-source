require "templateer.rb"
class TagDecorator < Draper::Decorator
  include Templateer
  delegate_all

  def title
    object.name
  end
end
