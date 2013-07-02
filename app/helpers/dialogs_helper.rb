# Helpers for building dialogs

module DialogsHelper
  
  def simple_modal(which, ttl, options={}, &block)
    options[:body_contents] = dialog_cancel_button (options[:close_label] || "Done")
    mf = modal_footer options
    options.delete :body_contents
    options[:body_contents] = 
      modal_body(options.slice(:style), &block)+mf
    [:style, :close_label].each { |k| options.delete k }
    modal_dialog(which,ttl,options).html_safe
  end
  
  def modal_dialog( which, ttl=nil, options={}, &block )
    for_bootstrap = options[:area].blank? || options[:area] != "at_top"
    header = modal_header( for_bootstrap, ttl, !options[:noflash])
    body = options[:body_contents] || with_output_buffer(&block)
    options[:class] = 
      [ "dialog", 
        which.to_s, 
        options[:area] || "floating", 
        ("hide" unless options[:show]),
        ("modal-pending fade" if for_bootstrap), 
        options[:class] 
      ].compact.join(' ')
    [:area, :show, :noflash, :modal, :body_contents].each { |k| options.delete k }
    options[:id] = "recipePowerDialog"
    options[:title] = ttl if ttl
    content_tag(:div, header+body, options).html_safe
  end
  
  def modal_header( for_bootstrap, ttl, doflash )
    # Render for a floating dialog unless an area is asserted OR we're rendering for the page
    content = if for_bootstrap
      content_tag( :div,         
        %Q{
          <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
          <h3>#{ttl}</h3>
        }.html_safe,
        class: "modal-header")
    else
      generic_cancel_button('X') 
    end
    content <<= (content_tag(:div, flash_all, class: "notifications-panel")) if doflash
    content.html_safe
  end
  
  def modal_body(options={}, &block)
    bd = options[:body_contents] || with_output_buffer(&block)
    options[:class] = "modal-body #{options[:class]}"
    content_tag(:div, flash_all + bd, options).html_safe
  end
  
  def modal_footer(options={}, &block)
    ft = options[:body_contents] || with_output_buffer(&block)
    content_tag :div, ft, class: "modal-footer #{options[:class]}"
  end
  
  # Place the header for a dialog, including setting its Onload function.
  # Currently handled this way (e.g., symbols that have been supported)
  #   :edit_recipe
  #   :captureRecipe
  #   :new_recipe (nee newRecipe)
  #   :sign_in
  def dialogHeader( which, ttl=nil, options={})
    # Render for a floating dialog unless an area is asserted OR we're rendering for the page
    area = options[:area] || "floating" # (@partial ? "floating" : "page")
    hide = options[:show] ? "" : "hide"
    classes = options[:class] || ""
    logger.debug "dialogHeader for "+globstring({dialog: which, area: area, ttl: ttl})
    # Assert a page title if given
    ttlspec = ttl ? %Q{ title="#{ttl}"} : ""
    for_bootstrap = options[:area].blank? || options[:area] != "at_top"
    bs_classes = for_bootstrap ? "modal-pending hide fade" : ""
    hdr = 
      %Q{<div id="recipePowerDialog" class="#{bs_classes} dialog #{which.to_s} #{area} #{classes}" #{ttlspec}>}+
      (for_bootstrap ? 
        content_tag( :div,         
          %Q{
            <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
            <h3>#{ttl}</h3>
          }.html_safe,
          class: "modal-header") :
        generic_cancel_button('X') 
      )
      hdr <<= (content_tag(:div, "", class: "notifications-panel")+flash_all) unless options[:noflash]
    hdr.html_safe
  end

  def dialogFooter()
    "</div><br class='clear'>".html_safe
  end
  
  def generic_cancel_button name, options={}
    content_tag( :div, 
        %q{<a href="#" id="recipePowerCancelBtn" onclick="RP.dialog.cancel(event); return false;" style="text-decoration: none;">X</a>}.html_safe,
        class: "recipePowerCancelDiv")
  end
  
  def dialog_cancel_button name, options={}
    options[:class] = "#{options[:class]} btn btn-info"
    link_to_function name, "RP.dialog.cancel(event);", options
  end
    
end
