require 'templateer.rb'
class SiteDecorator < CollectibleDecorator
  include Templateer
  delegate_all

  # Standard accessors for model attributes

  def attribute_for what
    case default = super
      when :title
        :name
      when :image
        :logo
      when :url
        :home
      else
        default
    end
  end

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
    site.recipe_page_refs.destroy_all if site.recipes.empty?

    assocs = PageRef.types.collect { |prt| "#{prt}_page_refs".to_sym } << :feeds
    assocs.each { |assoc|
      site.errors.add(assoc, 'not empty') if site.method(assoc).call.exists?
    }

    # Normally we can't destroy a site if there are any dependent definition page refs.
    # We make an exception for cases where the site home is the same as the page ref.
    dpr_urls = site.definition_page_refs.pluck(:url).uniq
    if (dpr_urls.count == 1) && (cleanpath(site.home) == cleanpath(dpr_urls.first))
      site.errors.delete(:definition_page_refs)
      site.definition_page_refs.destroy_all
    end

    site.destroy unless site.errors.any?
  end

  def after_gleaning gleaning=object.gleaning
    gleaning.extract1 'Title' do |value|
      object.name = value
    end unless object.referent

    gleaning.extract1 'Description' do |value|
      object.description = value
    end unless object.description.present?
    object.save if object.changed?
  end

  def assert_gleaning gleaning
    gleaning.extract1 'Image' do |value| object.logo = value end
    gleaning.extract1 'URI' do |value| object.home = value end
    gleaning.extract_all 'RSS Feed' do |value| object.assert_feed value end
    gleaning.extract1 'Title' do |value| object.name = value end
    gleaning.extract1 'Description' do |value| object.description = value end
  end

end
