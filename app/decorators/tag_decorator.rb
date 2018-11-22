require "templateer.rb"
class TagDecorator < ModelDecorator
  include Templateer
  delegate_all

  def title
    object.name
  end

end
