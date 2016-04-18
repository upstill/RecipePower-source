require "templateer.rb"
class SiteDecorator < CollectibleDecorator
  include Templateer
  delegate_all

  # Standard accessors for model attributes

  def title
    object.name
  end

  def description
    object.description
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
