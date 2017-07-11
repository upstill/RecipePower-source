module GleaningsHelper

  # Declare an element that either provides gleaned choices, or waits for a replacement request to come in
  def gleaning_field decorator, what, gleaning=nil
    return unless gleaning ||= decorator.glean
    if gleaning.good?
      gleaning_field_declaration decorator, what, gleaning
    elsif glean_path = polymorphic_path([:glean, decorator], what: what) rescue nil
      glean_trigger = link_to_submit 'Scrape', glean_path, class: 'trigger hide'
      gleaning_field_enclosure what, glean_trigger+image_tag('ajax-loader.gif', class: 'beachball', style: 'height: 15px;')
    end
  end


  def gleaning_field_declaration decorator, what, gleaning=nil
    gleaning ||= decorator.gleaning
    label = {titles: 'Title', descriptions: 'Description', images: 'Image', feeds: 'RSS Feed'}[what]
    attribute_name = "#{decorator.param_key}[gleaning_attributes][#{label}]"
    target = nil
    field =
        case label
          when 'Title', 'Description'
            options = decorator.gleaning.options_for label
            target = "#{decorator.param_key}[#{decorator.attribute_for label}]"
            if label == 'Title' &&
                decorator.respond_to?(:page_ref) &&
                decorator.page_ref.title.present? &&
                !options.include?(decorator.page_ref.title)
              options << decorator.page_ref.title
            end
            if options.empty?
              content_tag :span, "(no #{label.pluralize.downcase} gleaned)"
            else
              select_tag attribute_name,
                         options_for_select(options),
                         prompt: "Gleaned #{(options.count > 1) ? label.pluralize : label}",
                         class: 'gleaning-select',
                         id: label
            end
          when 'RSS Feed'
            # Declare a checkbox and an external link to each feed link
            return unless decorator.object.is_a? Site
            gleaning = decorator.gleaning.extract_all 'RSS Feed' do |link, index|
              link = normalize_url link
              if fz = Feed.preload(link)
                entry_date = ", latest #{fz.entries.first.published.to_s.split.first}" if fz.entries.first
                '<br>' +
                    content_tag(:div,
                                check_box_tag(attribute_name+"[#{index}]",
                                              link,
                                              decorator.feeds.where(url: link).exists?
                                ),
                                style: 'display: inline-block; margin-right: 6px; margin-left: 5%'
                    ) +
                    label_tag(fz.title.present? ? fz.title : fz.description) +
                    '<br>'.html_safe +
                    content_tag(:div,
                                "-- #{pluralize(fz.entries.count, 'entry')}#{entry_date}",
                                style: 'display: inline-block; padding-left: 50px; font-size: 14px; margin-bottom: 9px;')
              end
            end
            if gleaning.present?
              label_tag('Gleaned Feeds') + gleaning.html_safe
            end
          when 'Image'
            if gleaning.images.present?
              content_tag(:span, 'Click on an image to grab it.', :class => 'prompt')
              pic_picker_select_list(gleaning.images || [])
            end
          when 'Tags'
          when 'Site Name'
          when 'Author'
          when 'Author Link'
        end
    gleaning_field_enclosure what, field, target
  end

  def gleaning_field_replacement decorator, what, gleaning=nil
    ['.'+gleaning_field_class(what), gleaning_field_declaration(decorator, what, gleaning)]
  end

  def gleaning_field_class what
    "gleaning-field-#{FinderServices.css_class what}"
  end

  def gleaning_field_enclosure what, content, target=nil
    klass = case what
      when :images
        'pic-pickees'
      else
        'gleaning-field-enclosure label-right' + gleaning_field_class(what)
    end + ' ' + gleaning_field_class(what)
    options = { class: klass }
    options[:data] = { target: target } if target
    content_tag :div, content, options
  end

  def gleaning_replacements decorator, what, gleaning=nil
    {
        replacements: [
            gleaning_field_replacement(decorator, what, gleaning)
        ]
    }
  end
end
