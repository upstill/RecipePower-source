module CardPresentation
  extend ActiveSupport::Concern

  def card_avatar options={}
    img = image_with_error_recovery decorator,
                                    class: decorator.image_class,
                                    fallback_img: options[:fallback_img] || decorator.object.is_a?(User),
                                    fill_mode: 'fixed-width'
    img = link_to_submit(img,
                         polymorphic_path([:editpic, decorator.object]),
                         mode: 'modal',
                         title: 'Get Picture') if permitted_to?(:update, decorator.object)
    img
  end

  # By default, show the card if there's an avatar OR a backup avatar
  def card_show_avatar
    (href = decorator.imgdata).present? ? href : h.image_path(decorator.fallback_imgdata)
  end

  # Provide the card's title with a link to the entity involved
  # NB This is meant to be overridden by entities (recipes, sites...) that link externally
  def card_homelink options={}
    (data = (options[:data] || {}))[:report] = h.polymorphic_path [:touch, decorator.object]
    homelink = h.polymorphic_path([:associated, decorator.object]) rescue nil
    homelink ||= h.polymorphic_path([:owned, decorator.object]) rescue nil
    link_to_submit decorator.title, (homelink || decorator.object), options.merge(:mode => :partial, :data => data)
  end

  def card_video
    if (url = URI(decorator.url)) &&
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
    label ||= which.to_s.capitalize.tr('_', ' ') # split('_').map(&:capitalize).join
    (
    content_tag(:p, label.upcase, class: "card-aspect-label #{which}") +
        content_tag(:p, contents, class: "card-aspect-contents #{which}")
    ).html_safe if contents.present?
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

  # Enumerate the aspects for a given column
  def card_aspects for_column
    []
  end

  def present_field_wrapped what=nil
    h.content_tag :span,
                  present_field(what),
                  class: "hide-if-empty"
  end

  def field_value what=nil
    return form_authenticity_token if what && (what == "authToken")
    if val = @decorator && @decorator.extract(what)
      "#{val}".html_safe
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

end
