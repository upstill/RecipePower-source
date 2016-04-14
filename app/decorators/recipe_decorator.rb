require 'string_utils.rb'
require "templateer.rb"
class RecipeDecorator < CollectibleDecorator
  include Templateer

  def external_link
    url
  end

  def findermap
    super.merge 'URI' => :url
  end

end
