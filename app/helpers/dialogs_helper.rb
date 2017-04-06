# Helpers for building dialogs

module DialogsHelper

  def injector_dialog which=:generic, hdr_text='', options={}, &block

    case dismiss_label = options[:dismiss_button]
      when nil
        dismiss_label = 'Okay'
      when false
        dismiss_label = nil
    end
    pic =
        content_tag :div,
                    image_tag(rp_url(image_path 'RP-logo-small-HC.png' ), class: 'small_logo', :alt => 'RecipePower'),
                    class: 'small_logo'
    body_content = with_output_buffer(&block)
    alert = options[:noflash] ? '' : (content_tag(:div, '', class: 'notifications-panel').html_safe+flash_all(false))

    content = injector_cancel_button('X') +
        content_tag(:div,
                    pic + content_tag(:div, hdr_text, class: 'injector-header-content').html_safe + '<hr>'.html_safe,
                    class: 'injector-header').html_safe

    content <<
        content_tag(:div,
                    alert.html_safe+body_content.html_safe,
                    class: 'injector-body').html_safe

    if dismiss_label
      content <<
          content_tag(:div,
                      dialog_cancel_button(dismiss_label),
                      class: 'injector-footer').html_safe
    end

    content_tag(:div,
                content.html_safe,
                class: "dialog injector #{which} ").html_safe
  end

  def simple_modal(which, ttl, options={}, &block)
    options[:body_contents] = dialog_cancel_button (options[:close_label] || 'Done')
    mf = modal_footer options
    options.delete :body_contents
    options[:body_contents] =
        modal_body(options.slice(:style), &block)+mf
    [:style, :close_label].each { |k| options.delete k }
    modal_dialog(which, ttl, options).html_safe
  end

  def modal_dialog(which, ttl=nil, options={}, &block)
    if ttl.is_a?(Hash)
      ttl, options = nil, ttl
    end
    dialog_class = options[:dialog_class]
    header = modal_header ttl, header_contents: options.delete(:header_contents)
    options[:body_contents] ||= with_output_buffer(&block)
    body = modal_body options.slice(:prompt, :body_contents, :noflash, :body_class)
    options[:class] =
        ['dialog hide',
         which.to_s,
         response_service.format_class,
         ('modal-pending fade' unless response_service.injector?),
         options[:class]
        ].compact.join(' ')
    # The :requires option specifies JS modules that this dialog uses
    options[:data] = {:'dialog-requires' => options[:requires]} if options[:requires]
    options = options.slice! :noflash, :body_contents, :body_class, :requires, :dialog_class
    options[:title] ||= ttl if ttl
    content_tag(:div, # Outer block: dialog
                content_tag(:div, # modal-dialog
                            content_tag(:div, header+body, class: 'modal-content'),
                            class: "modal-dialog #{dialog_class}"),
                options).html_safe
  end

  def modal_header ttl, options={}
    contents = options[:header_contents] ||
        (ttl.present? && content_tag(:h3, ttl)) ||
        ''
    response_service.injector? ?
        injector_cancel_button('X') :
        content_tag(:div, contents, class: 'modal-header')
  end

  def modal_body options={}, &block
    contents = ''
    contents << flash_notifications_div unless options.delete(:noflash)
    contents << content_tag(:div, prompt, class: 'prompt').html_safe if prompt = options.delete(:prompt)
    contents << (options.delete(:body_contents) || capture(&block))
    options[:class] = "modal-body #{options.delete :body_class}"
    contents = content_tag(:div, contents.html_safe, class: 'col-md-12')
    contents = content_tag(:div, contents.html_safe, class: 'row')
    content_tag(:div, contents.html_safe, options).html_safe
  end

  def modal_footer(options={}, &block)
    ft = options[:body_contents] || with_output_buffer(&block)
    content_tag :div, ft, class: "modal-footer row #{options[:class]}"
  end

  def pane_dialog decorator, colorscheme='green'
    bc = content_tag( :div, flash_notifications_div, class: 'notifications-panel')+
         render('form', decorator: decorator, in_panes: true)

    modal_dialog "pane_runner new-style #{colorscheme}",
                 header_contents: decorator.dialog_pane_buttons,
                 dialog_class: 'modal-lg',
                 body_contents: bc
  end

  def dialog_pane(name, inner_col=true, form_params={}, &block)
    if inner_col.is_a? Hash
      inner_col, form_params = true, inner_col
    end
    contents = block_given? ? with_output_buffer(&block) : render('form_content', form_params)
    contents = content_tag(:div,
                           contents,
                           class: 'col-md-12'
    ) if inner_col
    content_tag(:div,
                content_tag(:div, contents, class: 'row'),
                class: "#{name} pane",
                id: "#{name}-pane"
    ).html_safe
  end

  # Place the header for a dialog, including setting its Onload function.
  # Currently handled this way (e.g., symbols that have been supported)
  #   :edit_recipe
  #   :captureRecipe
  #   :new_recipe (nee newRecipe)
  #   :sign_in
  def dialogHeader(which, ttl=nil, options={})
    classes = options[:class] || ''
    logger.debug "dialogHeader for #{globstring({dialog: which, format: response_service.format_class, ttl: ttl})}"
    # Assert a page title if given
    ttlspec = ttl ? %Q{ title="#{ttl}"} : ''
    bs_classes = !response_service.injector? ? '' : 'modal-pending hide fade'
    hdr =
        %Q{<div class="#{bs_classes} dialog #{which.to_s} #{response_service.format_class} #{classes}" #{ttlspec}>}+
            (response_service.injector? ?
                injector_cancel_button('X') :
                content_tag(:div,
                            (dialog_cancel_button('&times;')+content_tag(:h3, ttl)),
                            class: 'modal-header')
            )
    hdr <<= (content_tag(:div, '', class: 'notifications-panel')+flash_all) unless options[:noflash]
    hdr.html_safe
  end

  def dialogFooter()
    "</div><br class='clear'>".html_safe
  end

  def injector_cancel_button name, options={}
    xlink = link_to '&nbsp;X&nbsp;'.html_safe,
                    '#',
                    id: 'recipePowerCancelBtn'
    content_tag :div,
                xlink,
                id: 'recipePowerCancelDiv'
  end

  def dialog_submit_button label = nil, options={}
    if label.is_a? Hash
      options, label = label, nil
    end
    options = bootstrap_button_options options.merge(
                                           button_style: (options[:button_style] || 'success'),
                                           class: "#{options[:class]} #{options[:style] || 'form-button'}"
                                       )
    tag :input,
        class: "#{options[:class]} dialog-submit-button",
        name: 'commit',
        type: 'submit',
        value: label||'Save',
        data: { method: options[:method] || 'post' }
  end

  def dialog_cancel_button label = nil, options={}
    if label.is_a? Hash
      options, label = label, nil
    end
    options = bootstrap_button_options options.merge(
                                           button_style: (options[:button_style] || 'info'),
                                           class: "#{options[:class]} #{options[:style] || 'form-button'}"
                                       )
    tag :input,
        class: "#{options[:class]} cancel dialog-cancel-button",
        data: {dismiss: 'modal'},
        name: 'commit',
        type: 'submit',
        value: label||'Cancel'
  end
end
