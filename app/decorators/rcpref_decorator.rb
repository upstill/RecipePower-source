require "templateer.rb"
class RcprefDecorator < Draper::Decorator
  include Templateer
  delegate_all

  def dom_id
    "#{object.entity.class.to_s.downcase}_#{object.entity.id}"
  end

end
