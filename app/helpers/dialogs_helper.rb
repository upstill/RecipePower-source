# Helpers for building dialogs

module DialogsHelper
  
  def injector_dialog which=:generic, hdr_text="", options={}, &block
    
    case dismiss_label = options[:dismiss_button]
    when nil
      dismiss_label = "Okay"
    when false
      dismiss_label = nil
    end
  	pic = 
  	content_tag :div, 
  	    image_tag( "http://www.recipepower.com/assets/RPlogo.png", class: "small_logo", :alt => "RecipePower"), 
  	    class: "small_logo"
    body_content = with_output_buffer(&block)
    alert = options[:noflash] ? "" : (content_tag(:div, "", class: "notifications-panel").html_safe+flash_all(false))
    
    content = generic_cancel_button('X') + 
      content_tag( :div,
        pic + content_tag(:div, hdr_text, class: "injector-header-content").html_safe,
        class: "injector-header").html_safe
        
    content <<
      content_tag( :div,
        alert.html_safe+body_content.html_safe,
        class: "injector-body").html_safe
        
    if dismiss_label
      content <<
      content_tag( :div, 
        dialog_cancel_button(dismiss_label),
        class: "injector-footer").html_safe
    end
    
    content_tag( :div,
      content.html_safe,
      class: "dialog injector #{which} at_top").html_safe
  end
  
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
        ("modal-pending fade" if for_bootstrap && !options[:show]), 
        options[:class] 
      ].compact.join(' ')
    # The :requires option specifies JS modules that this dialog uses
    options[:data] = { :"dialog-requires" => options[:requires] } if options[:requires]
    options = options.slice! :area, :show, :noflash, :modal, :body_contents, :requires
    # options[:id] = "recipePowerDialog"
    options[:title] = ttl if ttl
    content_tag(:div, header+body, options).html_safe
  end
  
  def modal_header( for_bootstrap, ttl, doflash )
    # Render for a floating dialog unless an area is asserted OR we're rendering for the page
    content = if for_bootstrap
      content_tag( :div,         
        %Q{
          <button type="button" class="close" onclick="RP.dialog.cancel(event);" aria-hidden="true">&times;</button>
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
    if prompt = options.delete( :prompt )
      prompt = content_tag( :div, prompt, class: "prompt" ).html_safe
    end
    options[:class] = "modal-body #{options[:class]}"
    content_tag(:div, "#{prompt}#{flash_all}#{bd}".html_safe, options).html_safe
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
    classes = options[:class] || ""
    logger.debug "dialogHeader for "+globstring({dialog: which, area: area, ttl: ttl})
    # Assert a page title if given
    ttlspec = ttl ? %Q{ title="#{ttl}"} : ""
    for_bootstrap = options[:area].blank? || options[:area] != "at_top"
    bs_classes = for_bootstrap ? "modal-pending hide fade" : ""
    hdr = 
      %Q{<div class="#{bs_classes} dialog #{which.to_s} #{area} #{classes}" #{ttlspec}>}+
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
    options[:class] = "#{options[:class]} btn btn-success dialog-cancel-button"
    link_to name, "#", options
  end
    
end
