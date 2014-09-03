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
        ("<hr>"+alert).html_safe+body_content.html_safe,
        class: "injector-body").html_safe
        
    if dismiss_label
      content <<
      content_tag( :div, 
        dialog_cancel_button(dismiss_label),
        class: "injector-footer").html_safe
    end
    
    content_tag( :div,
      content.html_safe,
      class: "dialog injector #{which} ").html_safe
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
    dialog_class = options[:dialog_class]
    header = modal_header ttl 
    options[:body_contents] ||= with_output_buffer(&block)
    body = modal_body options.slice(:prompt, :body_contents, :noFlash, :body_class)
    options[:class] = 
      [ "dialog", 
        which.to_s, 
        response_service.format_class,
        ("hide" unless options[:show]),
        ("modal-pending fade" unless response_service.injector? || options[:show]), 
        options[:class] 
      ].compact.join(' ')
    # The :requires option specifies JS modules that this dialog uses
    options[:data] = { :"dialog-requires" => options[:requires] } if options[:requires]
    options = options.slice! :show, :noflash, :body_contents, :body_class, :requires
    options[:title] ||= ttl if ttl
    content_tag(:div, # Outer block: dialog
      content_tag(:div, # modal-dialog
        content_tag(:div, header+body, class: "modal-content"), 
        class: "modal-dialog #{dialog_class}"),
      options).html_safe
  end
  
  def modal_header( ttl )
    content = 
      response_service.injector? ? 
      generic_cancel_button('X') :
      content_tag( :div,         
        %Q{
          <button type="button" class="close" onclick="RP.dialog.cancel(event);" aria-hidden="true">&times;</button>
          <h3>#{ttl}</h3>
        }.html_safe,
        class: "modal-header")
    content.html_safe
  end
  
  def modal_body(options={}, &block)
    contents = ""
    contents << flash_notifications_div("notifications-panel") unless options.delete(:noFlash)
    contents << content_tag( :div, prompt, class: "prompt" ).html_safe if prompt = options.delete( :prompt )
    contents << ( options.delete(:body_contents) || capture(&block) )
    options[:class] = "modal-body #{options.delete :body_class}"
    contents = content_tag(:div, contents.html_safe, class: "col-md-12")
    contents = content_tag(:div, contents.html_safe, class: "row")
    content_tag(:div, contents.html_safe, options).html_safe
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
    classes = options[:class] || ""
    logger.debug "dialogHeader for "+globstring({dialog: which, format: response_service.format_class, ttl: ttl})
    # Assert a page title if given
    ttlspec = ttl ? %Q{ title="#{ttl}"} : ""
    bs_classes = !response_service.injector? ? "" : "modal-pending hide fade"
    hdr = 
      %Q{<div class="#{bs_classes} dialog #{which.to_s} #{response_service.format_class} #{classes}" #{ttlspec}>}+
      (response_service.injector? ? generic_cancel_button('X') :
        content_tag( :div,         
          %Q{
            <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
            <h3>#{ttl}</h3>
          }.html_safe,
          class: "modal-header")
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
  
  def dialog_cancel_button name = "Cancel", options={}
    options[:class] = "#{options[:class]} btn btn-lg btn-info dialog-cancel-button"
    link_to name, "#", options
  end
    
end
