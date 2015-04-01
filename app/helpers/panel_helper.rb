module PanelHelper

  # Declare a link which changes the panel state and triggers an update
  def panel_querify_link label, qparams={}
    if label.is_a? Hash
      label, qparams = "", label
    end
    klass = qparams.delete :class
    link_to_submit label,
                   "#",
                   class: klass,
                   onclick: "RP.querify.onclick(event);",
                   querify: qparams
  end

  # The collapse button will be to collapse down (for masonry display) or up (for slider)
  def panel_collapse_button type, item_mode
    case item_mode
      when :masonry
        to_state, to_mode = :up, :slider
      when :slider
        to_state, to_mode = :down, :masonry
    end
    panel_querify_link item_mode: to_mode,
                   class: "collapse-button #{type} glyphicon glyphicon-collapse-#{to_state}"
  end

  def panel_collapse_button_replacement type, item_mode
    ["a.collapse-button.#{type}", panel_collapse_button(type, item_mode)]
  end

  def panel_org_button type, cur_org
    links = [ [:rating, "my rating" ], :popularity, :newest, [ :random, "hit me" ] ].collect { |org|
      org, label = org.is_a?(Array) ? org : [ org, org.to_s ]
      klass = "link"
      if org==cur_org
        klass << " selected"
        link = label
      else
        # Provide a link to change the org state
        link = panel_querify_link label, org: org
      end
      content_tag :span, link, class: klass
    }.join.html_safe
    label = content_tag :span, "Organize by:", class: "label"
    content_tag :div, (label+links).html_safe, class: "org-by #{type}"
  end

  def panel_org_button_replacement type, org
    ["div.org-by.#{type}", panel_org_button(type, org) ]
  end

  def panel_suggestion_button type
    panel_querify_link content_tag(:i, "", class: "suggest #{type} icon-large icon-lightbulb")
  end

  def panel_suggestion_button_replacement type
    [ "a.suggest.#{type}", panel_suggestion_button(type) ]
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