module GleaningsHelper

  # Declare an element that either provides gleaned choices, or waits for a replacement request to come in
  def gleaning_field decorator, label
    if decorator.gleaning && decorator.gleaning.good?
      gleaning_field_declaration decorator, label
    else
      gleaning_field_enclosure label,
                               image_tag('ajax-loader.gif', class: 'beachball', style: 'height: 15px;')
    end
  end

  # Define a trigger link to fetch the gleaning field(s), iff needed
  def gleaning_trigger decorator
    link_to_submit 'Scrape',
                   gleaning_path(decorator.gleaning),
                   class: 'trigger hide' unless !decorator.gleaning || decorator.gleaning.good?
  end

  def gleaning_field_declaration decorator, label
    entity_name = decorator.object.class.to_s.underscore
    attribute_name = "#{entity_name}[gleaning_attributes][#{label}]"
    target = nil
    field =
        case label
          when 'Title', 'Description'
            options = decorator.gleaning.options_for label
            target = "#{decorator.object.class.to_s.underscore}[#{decorator.attribute_for label}]"
            if label == 'Title' && decorator.respond_to?(:page_ref) && decorator.page_ref.title.present?
              options << decorator.page_ref.title
            end
            if options.empty?
              content_tag :span, "No #{label.pluralize} Gleaned"
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
          when 'Tags'
          when 'Site Name'
          when 'Author'
          when 'Author Link'
        end
    gleaning_field_enclosure label, field, target
  end

  def gleaning_field_replacement decorator, label
    [ '.'+gleaning_field_class(label), gleaning_field_declaration(decorator, label) ]
  end

  def gleaning_field_class label
    "gleaning-field-#{FinderServices.css_class label}"
  end

  def gleaning_field_enclosure label, content, target=nil
    content_tag :div,
                content,
                style: 'display: inline-block; width: 100%',
                class: 'gleaning-field-enclosure ' + gleaning_field_class(label),
                data: { target: target }.compact
  end
end
