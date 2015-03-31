module PanelHelper
  # The collapse button will be to collapse down (for masonry display) or up (for slider)
  def panel_collapse_button state
    qparam = {item_mode: (state == :down ? "masonry" : "slider")}
    link_to_submit content_tag(:span, "", class: "glyphicon glyphicon-collapse-#{state}"),
                     "#",
                     class: "collapse-button",
                     onclick: "RP.querify.onclick(event);",
                     data: {querify: qparam}
  end

  def panel_collapse_button_replacement state
    ['a.collapse-button', panel_collapse_button(state)]
  end
end