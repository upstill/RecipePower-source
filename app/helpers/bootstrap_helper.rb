module BootstrapHelper

  # Modify an options hash, setting the :class option to reflect :button_size and :button_style
  # SIDE EFFECT: deletes button options
  def bootstrap_button_options options
    if options[:button_size] || options[:button_style] || options.delete(:button)
      class_str = (options[:class] || "").gsub(/btn[-\w]*/i, '') # Purge the class of existing button classes
      btn_size_class = "btn-#{options[:button_size]}" unless options[:button_size].blank? # Allows for default, unspecified size
      options.delete :button_size
      btn_style_class = "btn-#{options.delete(:button_style) || 'default'}"
      btn_block_class = "btn-block" if options.delete(:button_block)
      options[:class] = "#{class_str} btn #{btn_style_class} #{btn_size_class} #{btn_block_class}"
    end
    options
  end

end