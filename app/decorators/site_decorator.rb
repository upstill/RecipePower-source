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

  def assert_gleaning gleaning
    gleaning.extract1 'Image' do |value| object.logo = value end
    gleaning.extract1 'URI' do |value| object.home = value end
    gleaning.extract_all 'RSS Feed' do |value| object.assert_feed value end
    gleaning.extract1 'Title' do |value| object.name = value end
    gleaning.extract1 'Description' do |value| object.description = value end
  end

  # When attributes are selected directly and returned as gleaning attributes, assert them into the model
  def assert_gleaning_attribute label, value
    case label
      when 'RSS Feed'
        # The 'value' is a list of feeds
        [value].flatten.map { |url|
          object.assert_feed url, true
        }
    end
  end

end
