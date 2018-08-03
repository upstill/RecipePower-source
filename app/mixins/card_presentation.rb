module CardPresentation
  require 'truncato'
  extend ActiveSupport::Concern

  # Provide the card's title with a link to the entity involved
  # NB This is meant to be overridden by entities (recipes, sites...) that link externally
  def card_homelink options={}
    homelink decorator, options
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
    which = which.to_s
    if contents.present?
      label ||= which.capitalize.tr('_', ' ')
      (label.present? ? h.content_tag(:h3, label.upcase, class: 'card-aspect-label ' + which) : ''.html_safe) +
      h.content_tag(:div, contents, class: 'card-aspect-contents ' + which)
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

  def card_avatar_column
    # nil by default
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
    decorator.object.is_a?(Taggable) ? decorator.individual_tagtypes : []
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
    label = nil
    contents =
    case which.to_sym
      when :authToken
        form_authenticity_token
      when :description
        label = ''
        decorator.description.html_safe if decorator.respond_to?(:description) && decorator.description
      else # Fall back on the decorator's version
        self.respond_to?(:present_field) ? present_field(which) : decorator.extract(which)
    end
    [ label || which.to_s.capitalize.tr('_', ' ').to_sym, contents]
  end

  def field_value what=nil
    return form_authenticity_token if what && (what == 'authToken')
    if val = @decorator && @decorator.extract(what)
      val.html_safe
    end
  end

  def present_field what, trunc=0
    str = field_value(what) || %Q{%%#{what.to_s}%%}
    # We want to keep the field from getting too long, but it may contain HTML tags
    # that could be violated by simple string truncation. Truncato respects tag boundaries,
    # and also can keep the tags themselves out of the length count.
    # For the sake of efficiency, we only resort to Truncato based on the full length of the string
    # including tags.
    str = Truncato.truncate(str, max_length: trunc-10, count_tags: false) if trunc > 10 && str.length > trunc
    str.html_safe
  end

  def field_count what
    @decorator && @decorator.respond_to?(:arity) && @decorator.arity(what)
  end

=begin
  def present_field_label
    label = what.sub '_tags', ''
    case field_count(what)
      when nil, false
        "%%#{what}_label_plural%%"+"%%#{what}_label_singular%%"
      when 1
        label.singularize
      else
        label.pluralize
    end
  end

  def present_field_wrapped what
    h.content_tag :span,
                  present_field(what),
                  class: 'hide-if-empty'
  end
=end

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
      title = decorator.title
      if options[:external]
        title << "  on #{decorator.site.name}" unless (entity.is_a?(Site)) || (entity.is_a?(PageRef) && entity.site?)
        link_to title, decorator.url, target: :_blank
      else
        link_to_submit title, linkpath(decorator), :mode => (options[:mode] || :partial)
      end
    }, (options[:joinstr] || ', ').html_safe
  end

  def card_video?
    false
  end

  def card_video
    nil
  end

  def card_avatar options={}
    nil
  end

  # Entities are editable, sharable, votable and collectible from the card by default
  def editable_from_card?
    true
  end

  def edit_button
    collectible_edit_button decorator if editable_from_card?
  end

  def tag_button
    collectible_tag_button(decorator) if decorator.object.is_a?(Taggable)
  end

  def tools_menu
    collectible_tools_menu decorator, 'lg' if editable_from_card? || response_service.admin_view?
  end

  def sharable_from_card?
    decorator.object.is_a? Collectible
  end

  def share_button
    collectible_share_button decorator, 'lg' if sharable_from_card?
  end

  def votable_from_card?
    decorator.object.is_a? Voteable
  end

  def vote_buttons
    collectible_vote_buttons decorator.object, class: 'stamp votes' if votable_from_card?
  end

  def collectible_from_card?
    decorator.object.is_a? Collectible
  end

  def collect_button
    collectible_collect_button decorator if collectible_from_card?
  end

end
