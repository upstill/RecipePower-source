class CardPresenter < BasePresenter

  def card_class
    "#{h.object_display_class decorator.object}-card"
  end

  def card_avatar with_form=false
    card_object_link image_with_error_recovery(decorator.imgdata(true), class: "fitPic", onload: 'doFitImage(event);', alt: decorator.fallback_imgdata)
  end

  # Take the opportunity to wrap the content in a link to the presented object
  def card_object_link content
    content # h.link_to_if(user.url.present?, content, user.url)
  end

  def card_header
    content = card_header_content + collectible_buttons_panel(@decorator,
                                         :button_size => "xs",
                                         :edit_button => response_service.admin_view?)
    # content_tag :p, "#{card_header_content}&nbsp;#{editlink}".html_safe, class: "card-aspect-label header"
    content_tag :div, content.html_safe, class: "card-aspect-label header"
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
      [ card_aspect_selector(which), repl ]
    end
  end

  def card_aspect_selector which
    "tr.#{which}"
  end

  def card_aspect_replacement which
    if repl = aspect(which)
      [ card_aspect_selector(which), repl ]
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
    return unless (content = card_aspects(which_column).collect { |aspect| card_aspect_rendered aspect }.join("\n")).present?
    content_tag :div, content.html_safe, class: "col-md-#{12/card_ncolumns}"
  end

  # Enumerate the aspects for a given column
  def card_aspects for_column
    [ ]
  end

end
