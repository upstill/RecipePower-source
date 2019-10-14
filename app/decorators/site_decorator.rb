require 'templateer.rb'
class SiteDecorator < CollectibleDecorator
  include Templateer
  delegate_all

  def self.attrmap
    super.merge :logo => :image, :name => :title, :home => :url
  end

  # Standard accessors for model attributes

  def title
    object.name
  end

  def title= t
    object.name = t
  end

  def image
    object.logo
  end

  def image=img
    object.logo = img
  end

  def url
    object.home
  end

  def url= url
    object.home = url
  end

  def site
    object
  end

  def external_link
    object.home
  end

  def sourcename
    ''
  end

  def sourcehome
    object.home
  end

  def sample_page
    object.home
  end

  def finderlabels
    super + %w{ Image URI RSS\ Feed }
  end

  # Managed deletion of site
  def destroy
    site = object

    # Clear all recipe page refs without associated (i.e., priorly destroyed) recipes
    site.page_refs.recipe.destroy_all if site.recipes.empty?

    site.errors.add(:feeds, 'not empty') if site.feeds.exists?
    site.errors.add(:page_refs, 'not empty') if site.page_refs.exists?

    # Normally we can't destroy a site if there are any dependent definition page refs.
    # We make an exception for cases where the site home is the same as the page ref.
    dpr_urls = site.page_refs.about.pluck(:url).uniq
    if (dpr_urls.count == 1) && (cleanpath(site.home) == cleanpath(dpr_urls.first))
      site.errors.delete(:page_refs)
      site.page_refs.destroy_all
    end

    site.destroy unless site.errors.any?
  end

  def after_gleaning gleaning=object.gleaning
    gleaning.result_for('Title') { |value| object.name = value } unless object.referent
    gleaning.result_for('Description') { |value| object.description = value } unless object.description.present?
    object.save if object.changed?
  end

  def eligible_tagtypes
    ([ :Ingredient, :Genre, :Occasion, :Dish, :Process, :Tool, :Course, :Diet ] + super).uniq # , :Dish, :Process, :Tool, :Course, :Diet
  end

end
