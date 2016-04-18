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
    field =
    case label
      when 'Title', 'Description'
        options = decorator.gleaning.options_for label
        select_tag attribute_name,
                   options_for_select(options),
                   prompt: "Gleaned #{(options.count > 1) ? label.pluralize : label}",
                   class: 'gleaning-select',
                   id: label
      when 'RSS Feed'
        # Declare a checkbox and an external link to each feed link
        gleaning = decorator.gleaning.extract_unique 'RSS Feed' do |link, index|
          if fz = Feed.preload(link)
            '<br>' +
            content_tag(:div,
                        check_box_tag( attribute_name+"[#{index}]", link),
                        style: 'display: inline-block; margin-right: 6px;'
            ) +
            label_tag((fz.title.present? ? fz.title : fz.description) + " (#{pluralize fz.entries.count, 'entry'})")
          end
        end
        if gleaning.present?
          label_tag('Possible Feeds') + gleaning.html_safe
        end
      when 'Image'
      when 'Tags'
      when 'Site Name'
      when 'Author Name'
      when 'Author Link'
    end
    gleaning_field_enclosure label, field
  end

  def gleaning_field_replacement decorator, label
    [ '.'+gleaning_field_class(label), gleaning_field_declaration(decorator, label) ]
  end

  def gleaning_field_class label
    "gleaning-field-#{Finder.css_class label}"
  end

  def gleaning_field_enclosure label, content
    content_tag :div,
                content,
                style: 'display: inline-block',
                class: 'gleaning-field-enclosure '+gleaning_field_class(label)
  end
end
