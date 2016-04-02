class SitePresenter < CollectiblePresenter
  presents :site
  delegate :name, :fullname, :lists, :feeds, to: :site

  def initialize decorator, template, viewer
    super
  end

  def card_header_content
    link_to site.name, site.home
  end
  alias_method :header, :card_header_content  # Backwards compatibility thing

=begin
  def aspects
    card_aspects.collect { |this| aspect(this) }.compact.join.html_safe
  end

  def about
    handle_none user.about do
      markdown(user.about)
    end
  end

  def tags
    user.tags.collect { |tag| tag.name }.join(', ')
  end
=end

  private

  def handle_none(value)
    if value.present?
      yield
    else
      h.content_tag :span, "None given", class: "none"
    end
  end

end
