require "templateer.rb"
class TaggingDecorator < ModelDecorator
  include Templateer
  delegate_all

end
