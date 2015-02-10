require "templateer.rb"
class TaggingDecorator < Draper::Decorator
  include Templateer
  delegate_all

end
