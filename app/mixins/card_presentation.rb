module CardPresentation
  extend ActiveSupport::Concern

  def card_avatar options={}
    img = image_from_decorator decorator
    if img && permitted_to?(:update, decorator.object)
      link_to_submit img,
                     polymorphic_path([:editpic, decorator.object]),
                     mode: 'modal',
                     title: 'Get Picture'
    else
      img
    end
  end

  # By default, show the card if there's an avatar OR a backup avatar
  def card_show_avatar
    (href = decorator.imgdata).present? ? href : h.image_path(decorator.fallback_imgdata)
  end

  # Provide the card's title with a link to the entity involved
  # NB This is meant to be overridden by entities (recipes, sites...) that link externally
  def card_homelink options={}
    homelink decorator, options
  end

  def card_video
    if decorator.url.present? &&
        (url = URI(decorator.url)) &&
        url.host.match(/\.youtube.com/) &&
        (vidlink = YouTubeAddy.extract_video_id(decorator.url))

       video_embed "https://www.youtube.com/embed/#{vidlink}"
    end
  end

  def card_header
    content_tag :div, card_header_content, class: "card-aspect-label header"
  end

  def card_header_content
    @decorator.title.downcase
  end

  def card_subhead
    if (subhead = card_subhead_content).present?
      content_tag :div, content_tag(:p, subhead), class: "panel_heading"
    end
  end

  def card_subhead_content
  end

  def card_aspect_enclosure which, contents, label=nil
    if contents.present?
      label ||= which.to_s.capitalize.tr('_', ' ')
      (label.present? ? h.content_tag(:p, label.upcase, class: "card-aspect-label #{which}") : ''.html_safe) +
      h.content_tag(:p, contents, class: "card-aspect-contents #{which}")
    end
  end

  def card_aspect_editor which
    card_aspect_enclosure which, with_format("html") { render "form_#{which}", user: viewer }
  end

  def card_aspect_editor_replacement which
    if repl = self.aspect_editor(which)
      [card_aspect_selector(which), repl]
    end
  end

  def card_aspect_selector which
    "tr.#{which}"
  end

  def card_aspect_replacement which
    if repl = aspect(which)
      [card_aspect_selector(which), repl]
    end
  end

  def card_aspect_rendered which
    label, contents = card_aspect which
    card_aspect_enclosure which, contents, label
  end

  # How many columns does the card have (next to the avatar)
  def card_ncolumns
    0
  end

  # Render the n-th column (limited by card_ncolumns)
  def column which_column
    return if (content = card_aspects(which_column).collect { |aspect| card_aspect_rendered aspect }.compact).empty?
    content_tag :div, safe_join(content), class: "col-md-#{12/card_ncolumns}"
  end

  # Enumerate the possible aspects of the card
  def card_aspects for_column=nil
    []
  end

  # Select available aspects according to the given arguments
  # The arguments are strings selecting particular aspects
  # A terminating options hash can provide exceptions
  def card_aspects_filtered *args
    aspects = card_aspects
    options = args.last.is_a?(Hash) ? args.pop : {}
    aspects -= options[:except] if options[:except]
    aspects
  end

  # Call the provided block for each aspect of the card
  def rendered_aspects *args
    card_aspects_filtered(*args).each do |aspect|
      contents = card_aspect_rendered aspect
      yield aspect.to_s, contents if contents.present?
    end
  end

  def card_aspect which
    contents =
    case which.to_sym
      when :authToken
        form_authenticity_token
      when :description
        label = ''
        decorator.description if decorator.respond_to?(:description)
      else # Fall back on the decorator's version
        self.respond_to?(:present_field) ? present_field(which) : decorator.extract(which)
    end
    [ which.to_s.capitalize.tr('_', ' ').to_sym, contents]
  end

  def present_field_wrapped what=nil
    h.content_tag :span,
                  present_field(what),
                  class: "hide-if-empty"
  end

  def field_value what=nil
    return form_authenticity_token if what && (what == "authToken")
    if val = @decorator && @decorator.extract(what)
      val.html_safe
    end
  end

  def present_field what=nil
    field_value(what) || %Q{%%#{(what || "").to_s}%%}.html_safe
  end

  def field_count what
    @decorator && @decorator.respond_to?(:arity) && @decorator.arity(what)
  end

  def present_field_label what
    label = what.sub "_tags", ''
    case field_count(what)
      when nil, false
        "%%#{what}_label_plural%%"+"%%#{what}_label_singular%%"
      when 1
        label.singularize
      else
        label.pluralize
    end
  end

  def field_label_counted what, count
    case count
      when 0
        ''
      when 1
        what.to_s.singularize
      else
        what.to_s.pluralize
    end
  end

  # Provide a list of links to a partial for the home of each entity
  def entity_links entities, options={}
    safe_join entities.collect { |entity|
      decorator = entity.decorate
      homelink = decorator.respond_to?(:homelink) ? decorator.homelink : linkpath(entity)
      link_to_submit decorator.title, homelink, :mode => (options[:mode] || :partial)
    }, (options[:joinstr] || ', ').html_safe
  end

end
