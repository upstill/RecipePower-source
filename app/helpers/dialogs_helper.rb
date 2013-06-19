# Helpers for building dialogs

module DialogsHelper
  
  def modal_dialog( which, ttl=nil, options={}, &block )
    options[:modal] = true if options[:modal].nil?
    dlg = with_output_buffer &block
    (dialogHeader(which, ttl, options)+
     dlg+
     dialogFooter).html_safe
  end
  
  def modal_body(style="", &block)
    bd = with_output_buffer &block
    content_tag :div, flash_all + bd, class: "modal-body #{style}"
  end
  
  def modal_footer(&block)
    ft = with_output_buffer &block
    content_tag :div, ft, class: "modal-footer"
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
    # class 'modal' is for use by Bootstrap modal; it's obviated when rendering to a page (though we can force
    # it for pre-rendered dialogs by asserting the :modal option)
    modal = options[:modal] ? "modal-pending hide" : ""
    logger.debug "dialogHeader for "+globstring({dialog: which, area: area, ttl: ttl})
    # Assert a page title if given
    ttlspec = ttl ? %Q{ title="#{ttl}"} : ""
    cancel_button = content_tag( :div, 
        %q{<a href="#" id="recipePowerCancelBtn" onclick="RP.dialog.cancel(); return false;" style="text-decoration: none;">X</a>}.html_safe,
        class: "recipePowerCancelDiv")
    hdr = 
      %Q{
        <div id="recipePowerDialog" class="#{modal} dialog #{which.to_s} #{area} #{classes}" #{ttlspec}>
        <div class="modal-header">
          <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
          <h3>#{ttl}</h3>
        </div>}+
      content_tag(:div, "", class: "notifications-panel")+
      flash_all
    hdr.html_safe
  end

  def dialogFooter()
    "</div><br class='clear'>".html_safe
  end
  
end
