require 'string_utils.rb'
require 'templateer.rb'
class RecipeDecorator < CollectibleDecorator
  include Templateer

  def self.attrmap
    super.merge :picurl => :image
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

  # When preview data comes in, trigger a redo of content
  def regenerate_dependent_content
    # Site trimmers and selectors require getting the PageRef to regenerate content
    # Refresh both the object's and its page_ref's content if the site's trimmers, selectors or finders have changed
    either = recipe_page && recipe_page.decorate.regenerate_dependent_content
    either = page_ref.decorate.regenerate_dependent_content || either
    # The recipe needs to be reparsed if the grammar_mods outside :rp_recipelist have changed
    either ||= site.grammar_mods.except(:rp_recipelist) != site.grammar_mods_was.except(:rp_recipelist).deep_symbolize_keys
    refresh_attributes :content if either || content_changed?
    either
  end

end
