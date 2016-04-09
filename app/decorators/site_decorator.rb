require "templateer.rb"
class SiteDecorator < CollectibleDecorator
  include Templateer
  delegate_all

  def title
    object.name
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

end
