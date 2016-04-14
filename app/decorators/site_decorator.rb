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

  # Give the mapping from finder labels to (possibly virtual) attributes
  def findermap
    super.merge 'Image' => :logo, 'URI' => :home, 'RSS Feed' => :ensure_feed, 'Title' => :name
  end

end
