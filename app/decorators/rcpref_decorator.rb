require "templateer.rb"
class RcprefDecorator < Draper::Decorator
  include Templateer
  delegate_all

end
