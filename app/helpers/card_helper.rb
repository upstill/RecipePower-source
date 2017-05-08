module CardHelper

  # Present one section of the tag info using a label, a (possibly empty) collection
  # of descriptive strings, and a classname for a span summarizing the section (presumably
  # because the individual entries are meant to show on a line).
  # If the collection is empty, we return nil; if the contentclass is blank we don't wrap it in a span
  def format_card_summary contentstrs, options
    contentclass = options[:contentclass] || 'tag_info_section_content'
    label = options[:label] || ''
    joinstr = options[:joinstr] || ', '
    if contentstrs && !contentstrs.empty?
      contentstr = contentclass.blank? ?
          contentstrs.join('').html_safe :
          content_tag(:span, contentstrs.join(joinstr).html_safe, class: contentclass)
      # content_tag( :div,
      #   (label+contentstr).html_safe,
      #  class: "info_section"
      # )
      result =
          content_tag :div,
                      content_tag( :div,
                                   content_tag(:p, "<strong>#{label}</strong>".html_safe, class: 'pull-right'),
                                   class: 'col-md-4')+
                          content_tag( :div,
                                       content_tag(:p, contentstr.html_safe, class: 'pull-left'),
                                       class: 'col-md-8'),
                      class: 'row'
      result.html_safe
    end
  end

end