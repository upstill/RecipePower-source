module PanelHelper

  # The collapse button will be to collapse down (for masonry display) or up (for slider)
  def panel_collapse_button type, item_mode
    case item_mode
      when :masonry
        to_state, to_mode = :up, :slider
      when :slider
        to_state, to_mode = :down, :masonry
    end
    querify_button :item_mode,
                   to_mode,
                   class: "collapse-button #{type.to_s.extensions_to_classes} glyphicon glyphicon-collapse-#{to_state}"
  end

  def panel_collapse_button_replacement type, item_mode
    selector = 'a.collapse-button'
    selector << '.' + type.extensions_to_selector if type.present?
    [selector, panel_collapse_button(type, item_mode)]
  end

  def panel_expand_link url, type
    link_to_submit "SEE ALL", assert_query(url, ResultType.new(type).params), :mode => :partial, class: "expand-link"
  end

  def panel_org_menu url, type, cur_org
=begin
    links = [ [:rating, 'my rating' ], :popularity, :newest, [ :random, 'hit me' ] ].collect { |org|
      org, label = org.is_a?(Array) ? org : [ org, org.to_s ]
      # Provide a button to change the org state
      link = querify_link label, assert_query(url, org: org), class: "link #{'selected' if org==cur_org}"
      content_tag :div, link, class: 'link-button'
    }.join.html_safe
    label = content_tag :span, 'organize by:', class: 'label'
    content_tag :div, label+links+(block_given? ? yield : ''.html_safe), class: "org-by #{type.to_s.extensions_to_classes}"
=end
    content_tag :div, (block_given? ? yield : ''.html_safe), class: "org-by #{type.to_s.extensions_to_classes}"
  end

  def panel_org_menu_replacement url, type, org
    selector = 'div.org-by'
    selector << '.' + type.extensions_to_selector if type.present?
    [selector, panel_org_menu(url, type, org) ]
  end

=begin
  def panel_suggestion_button url, type
    querify_link '', url, class: "suggest #{type.to_s.extensions_to_classes} icon-large icon-lightbulb"
  end

  def panel_suggestion_button_replacement url, type
    selector = 'a.suggest'
    selector << '.' + type.extensions_to_selector if type.present?
    [selector, panel_suggestion_button(url, type) ]
  end

=end
  def panel_suggestions_placeholder type
    content_tag :div, '', class: "suggestions #{type.to_s.extensions_to_classes} placeholder" # Placeholder for the suggestions panel
  end

  def panel_suggestions partial
    with_format('html') { render partial, decorator: @decorator, viewparams: @filtered_presenter.viewparams }
  end

  def panel_suggestions_replacement type, partial=nil
    selector = '.suggestions'
    selector << '.' + type.extensions_to_selector if type.present?
    [selector, (partial ? panel_suggestions(partial) : panel_suggestions_placeholder(type)) ]
  end

  def panel_body section
    panel = with_format('html') { render 'notifs/panel_body', section: section }
    panel
  end

  def panel_body_replacement signature
    section = notifs_section signature, :is_vis => true
    [ 'div.selectable.modal-body.'+section.signature, panel_body(section) ]
  end
end
