require 'string_utils.rb'
require "templateer.rb"
class RecipeDecorator < CollectibleDecorator
  include Templateer

  def external_link
    url
  end

  def finderlabels
    super << 'URI'
  end

  def assert_gleaning gleaning
    super if defined? super
    gleaning.extract1 'URI' do |value| object.url = value end
  end

end
