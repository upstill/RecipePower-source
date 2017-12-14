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

  def eligible_tagtypes
    ([ :Ingredient, :Genre, :Occasion, :Dish, :Process, :Tool, :Course, :Diet ] + super).uniq # , :Dish, :Process, :Tool, :Course, :Diet
  end

  def individual_tagtypes
    ([ :Ingredient, :Genre, :Occasion ] + super).uniq # , :Dish, :Process, :Tool, :Course, :Diet
  end


end
