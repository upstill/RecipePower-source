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

  def gleaning_field label
    case label
      when 'Title'
        h.gleaning_field site, label, 'input'
      when 'Description'
        h.gleaning_field site, label
    end
  end

  private

  def handle_none(value)
    if value.present?
      yield
    else
      h.content_tag :span, "None given", class: "none"
    end
  end

end
