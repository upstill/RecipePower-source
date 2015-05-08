class SitePresenter < CollectiblePresenter
  presents :site
  delegate :name, :fullname, :lists, :feeds, to: :site

  def initialize decorator, template, viewer
    super
  end

  def card_avatar_fallback
    "MissingLogo.png"
  end

  def card_header_content
    link_to site.name, site.home
  end
  alias_method :header, :card_header_content  # Backwards compatibility thing

  def card_aspect which, options = {}
    label = contents = nil
    case which
      when :description
        contents = site.description
      when :author
        tags = site.visible_tags :tagtype => :Author
        label = label.pluralize unless tags.empty?
        contents = tag_list tags
      when :tags
        tags = site.visible_tags :tagtype => [:Genre, :Role, :Ingredient, :Source, :Occasion, :Tool]
        label = label.pluralize unless tags.empty?
        contents = tag_list tags
      when :lists # Lists it appears under
        # TODO Shoud be including option of indirect linkage i.e. being tagged with a list's tag
        label = "Seen on list(s)"
        contents = strjoin(site.visible_tags(tagtype: :List).collect { |list_tag|
          link_to_submit(list.name, list_path(list), :mode => :partial)
        }).html_safe
    end
    [ label, contents ]
  end

  def card_aspects
    [ :author, :description, :tags, :title ]
  end

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
