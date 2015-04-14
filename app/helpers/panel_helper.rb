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
                   class: "collapse-button #{type} glyphicon glyphicon-collapse-#{to_state}"
  end

  def panel_collapse_button_replacement type, item_mode
    ["a.collapse-button.#{type}", panel_collapse_button(type, item_mode)]
  end

  def panel_org_menu url, type, cur_org
    links = [ [:rating, "my rating" ], :popularity, :newest, [ :random, "hit me" ] ].collect { |org|
      org, label = org.is_a?(Array) ? org : [ org, org.to_s ]
      if org==cur_org
        content_tag :span, label, class: "link selected"
      else
        # Provide a button to change the org state
        querify_link label, assert_query(url, org: org), class: "link"
      end
    }.join.html_safe
    label = content_tag :span, "Organize by:", class: "label"
    content_tag :div, (label+links).html_safe, class: "org-by #{type}"
  end

  def panel_org_menu_replacement url, type, org
    ["div.org-by.#{type}", panel_org_menu(url, type, org) ]
  end

  def panel_suggestion_button url, type
    querify_link "", url, class: "suggest #{type} icon-large icon-lightbulb"
  end

  def panel_suggestion_button_replacement url, type
    [ "a.suggest.#{type}", panel_suggestion_button(url, type) ]
  end
  
  def panel_results_placeholder type
    content_tag :div, "", class: "results #{type} placeholder"
  end
  
  def panel_results partial
    with_format("html") { render partial }
  end
  
  def panel_results_replacement type, partial
    [ ".results.#{type}", panel_results(partial) ]
  end
end
