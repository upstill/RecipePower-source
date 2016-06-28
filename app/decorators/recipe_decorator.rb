require 'string_utils.rb'
require 'templateer.rb'
class RecipeDecorator < CollectibleDecorator
  include Templateer

  def attribute_for label
    case default = super
      when :image
        :picurl
      else
        default
    end
  end

  def image
    object.picurl
  end

  def image=img
    object.picurl = img
  end

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

  def presentable_tagtypes
    super # [ :Process, :Tool, :Occasion, :Source, :Genre, :Ingredient, :Dish, :Diet, :Author, :Course ]
  end

end
