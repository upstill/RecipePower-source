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
    alert = options[:noflash] ? '' : (content_tag(:div, '', class: 'notifications-panel').html_safe+flash_all)

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

  # Construct a dialog that offers the user a choice of actions.
  # Each choice will be expressed as a button with a label that will be passed back to the controller under :button_name
  # title: the header string in the dialog
  # style: the style
  # options:
  #     :entity: either a string for a path, or an entity which will be hit with a PATCH directive that handles the
  #               patch in accordance with the button name
  #     :choices: an array of strings, or string/button style pairs, for the buttons. The possible styles
  #               are according to Bootstrap: https://www.w3schools.com/bootstrap/bootstrap_buttons.asp
  #     :prompt: the question being posed to the user
  def choice_alert title, style, options={}, &block
    styles = %w{ success primary }
    button_options = (options.delete(:choices) || []).reverse.collect { |choice| choice.is_a?(Array) ? choice : [ choice, (styles.pop || 'default')]}
    prompt = options.delete(:prompt) || ''
    entity = options.delete :entity
    options[:body_contents] =
        render layout: 'application/alert_body', locals: { prompt: prompt, entity: entity, button_options: button_options } do |f|
          yield f
        end
    modal_dialog style, title, options
  end

  # Present a modal dialog
  # which: CSS class for dialog, including color scheme, one of 'green', 'salmon', 'purple', 'blue', 'list-dialog', 'feed-dialog'
  # ttl: the title to be displayed in the header
  # block: declares the contents
  # options:
  #     dialog_class:
  #     header_contents:
  #     requires: JS modules this dialog requires
  #     body_contents: (passed to modal_body) declares body directly, obviating call to &block
  #     prompt: (passed to modal_body)
  #     noflash: (passed to modal_body)
  #     body_class: (passed to modal_body)
  def modal_dialog(which, ttl=nil, options={}, &block)
    if ttl.is_a?(Hash)
      ttl, options = nil, ttl
    end
    dialog_class = options[:dialog_class]
    header = modal_header ttl, header_contents: options.delete(:header_contents)
    options[:body_contents] ||= with_output_buffer(&block).if_present
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
        content_tag(:div, contents, options.slice(:style).merge(class: "modal-header #{options[:class]}"))
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

  # Produce a modal dialog divided into panes according to the decorator, as provided by the DialogPanes module
  def pane_dialog decorator, options={}
    colorscheme = options[:colorscheme] || 'green'
    bc = content_tag(:div, flash_notifications_div, class: 'notifications-panel')+
        render('form', decorator: decorator, in_panes: true)
    topics = strjoin(response_service.topics.split(',').map(&:capitalize)) if response_service.topics
    modal_dialog "pane_runner #{options[:dialog_class]} new-style #{colorscheme}",
                 "Edit #{decorator.object.class.to_s} #{topics}",
                 header_contents: dialog_pane_buttons(decorator),
                 dialog_class: 'modal-lg',
                 body_contents: bc
  end

  # Declare the buttons for switching amongst panes in the dialog
  def dialog_pane_buttons decorator
    input = '<input type="radio" name="options" autocomplete="off" checked '
    active = 'active' # Marks the input
    btns = decorator.dialog_pane_list.collect { |spec|
      label = content_tag :label,
                            (input + "data-pane='#{spec[:css_class]}'> " + spec[:label]).html_safe,
                            class: 'btn btn-primary ' + active
      active = ''
      input.sub! 'checked', ''
      label
    }.compact
    content_tag(:div,
                  safe_join(btns),
                  class: 'btn-group',
                  id: 'paneButtons',
                  data: {toggle: 'buttons'},
                  role: 'group') if btns.count > 1
  end

  def dialog_pane(pane_spec, inner_col=true, form_params={}, &block)
    if inner_col.is_a? Hash
      inner_col, form_params = true, inner_col
    end
    contents = block_given? ? with_output_buffer(&block) : render('form_content', form_params)
    contents = content_tag(:div,
                           contents,
                           class: 'col-md-12'
    ) if inner_col
    name = pane_spec[:css_class]
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

  def dialog_action_buttons decorator
    dialog_submit_button +
        if decorator.respond_to?(:regenerate_dependent_content)
          # The Cancel button will have to restore prior state if we're previewing
               dialog_submit_button('Cancel', button_style: 'info', data: {update_option: :restore}) +
              # Preview the results of the changes
              dialog_submit_button('Preview', button_style: 'primary', data: {update_option: :regenerate_dependent_content})
        else
          dialog_cancel_button
        end
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
    options[:class] << ' dialog-submit-button'
    options[:data] ||= {}
    options[:data][:method] = options[:method] || 'post'
    tag :input, { name: 'commit', type: 'submit', value: label||'Save' }.merge(options)
  end

  def dialog_answer_button label = nil, options={}
    if label.is_a? Hash
      options, label = label, nil
    end
    options = bootstrap_button_options options.merge(
                                           button_style: (options[:button_style] || 'success'),
                                           class: "#{options[:class]} #{options[:style] || 'form-button'}"
                                       )
    # submit_tag label, name: label, data: { name: label }
    tag :input,
        class: "#{options[:class]} dialog-submit-button",
        name: 'commit',
        type: 'submit',
        value: label||'Save',
        data: { name: label, method: options[:method] || 'post' }
  end

  # Present an 'X' close button at the top right of a dialog
  def dialog_close_button do_cancel = true, options={}
    content_tag :button,
                'x',
                options.merge(class: "#{options[:class]} close dialog-x-box #{'dialog-cancel-button' if do_cancel}")
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
        data: {dismiss: 'modal'}.merge(options[:data] || {}),
        name: 'commit',
        type: 'submit',
        value: label||'Cancel'
  end
end
