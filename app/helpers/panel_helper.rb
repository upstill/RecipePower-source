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
    ["a.collapse-button.#{type.extensions_to_selector}", panel_collapse_button(type, item_mode)]
  end

  def panel_expand_link url, type
    link_to_submit "SEE ALL", assert_query(url, entity_type: type), :mode => :partial, class: "expand-link"
  end

  def panel_org_menu url, type, cur_org
    links = [ [:rating, "my rating" ], :popularity, :newest, [ :random, "hit me" ] ].collect { |org|
      org, label = org.is_a?(Array) ? org : [ org, org.to_s ]
      # Provide a button to change the org state
      link = querify_link label, assert_query(url, org: org), class: "link #{'selected' if org==cur_org}"
      content_tag :div, link, class: "link-button"
    }.join.html_safe
    label = content_tag :span, "organize by:", class: "label"
    content_tag :div, (label+links).html_safe, class: "org-by #{type.to_s.extensions_to_classes}"
  end

  def panel_org_menu_replacement url, type, org
    ["div.org-by.#{type.extensions_to_selector}", panel_org_menu(url, type, org) ]
  end

  def panel_suggestion_button url, type
    querify_link '', url, class: "suggest #{type.to_s.extensions_to_classes} icon-large icon-lightbulb"
  end

  def panel_suggestion_button_replacement url, type
    [ "a.suggest.#{type.extensions_to_selector}", panel_suggestion_button(url, type) ]
  end
  
  def panel_results_placeholder type
    content_tag :div, '', class: "results #{type.to_s.extensions_to_classes} placeholder"
  end

  def panel_results partial
    with_format('html') { render partial }
  end

  def panel_results_replacement type, partial
    [ ".results.#{type.extensions_to_selector}", panel_results(partial) ]
  end

  def panel_suggestions_placeholder type
    content_tag :div, '', class: "suggestions #{type.to_s.extensions_to_classes} placeholder" # Placeholder for the suggestions panel
  end

  def panel_suggestions partial
    with_format('html') { render partial }
  end

  def panel_suggestions_replacement type, partial=nil
    [ ".suggestions.#{type.extensions_to_selector}", (partial ? panel_suggestions(partial) : panel_suggestions_placeholder(type)) ]
  end
end
