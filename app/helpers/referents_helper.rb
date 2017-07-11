module ReferentsHelper

=begin
  def referent_homelink ref, options={}
    homelink ref.becomes(Referent), options
  end
=end

  def summarize_ref_name referent, long=false
    extra = long ? 'going by the name of ' : ''
    "<i>#{referent.typename}</i> #{extra}<strong>'#{referent.name}'</strong> ".html_safe
  end

  def summarize_referent ref, options={}
    separator = summary_separator options[:separator]
    header, inward_separator = '', summary_separator(separator)
    if options[:header] || options[:label]
      header = safe_join([
                             (options[:label] || 'Meaning'),
                             homelink(ref.becomes(Referent))
                         ], ': '.html_safe,
      )
    end
    return header if separator.length > 15
    summarize_set '',
                  [
                      header,
                      summarize_ref_expressions(ref, separator: inward_separator),
                      summarize_ref_parents(ref, separator: inward_separator),
                      summarize_ref_children(ref, separator: inward_separator),
                      summarize_ref_affiliates(ref, separator: inward_separator)
                  ],
                  separator
  end

  def summarize_ref_expressions referent, options={}
    label = 'Expression'
    ct = referent.expressions.count
    label = labelled_quantity(ct, label) if ct > 1
    summarize_set label,
                  referent.expressions.limit(8).collect { |expr|
                    homelink(expr.tag, nuke_button: referent.expressions.count > 1)
                  },
                  options[:separator]
  end

  def summarize_ref_parents ref, options={}
    summarize_set (options[:label] || 'Categorized under'),
                  ref.parents.limit(8).collect { |parent| homelink parent.becomes(Referent) },
                  options[:separator]
  end

  def summarize_ref_children ref, options={}
    summarize_set (options[:label] || 'Category includes'),
                  ref.children.limit(8).collect { |child| homelink child.becomes(Referent) },
                  options[:separator]
  end

  def summarize_ref_affiliates ref, options={}
    affiliate_descriptors =
        ref.affiliates.collect { |affil|
          case affil
            when Referent
              summarize_referent affil, options.merge(label: affil.model_name.human.split(' ').first)
            when PageRef
              present_page_ref affil, options.merge(label: 'About') # affil.model_name.human.sub(/ ref$/,''))
            else
              safe_join [affil.model_name.human.split(' ').first.html_safe, homelink(affil)], ': '
          end
        }.compact
    summarize_set (options[:label] || 'Associated with'),
                  affiliate_descriptors,
                  options[:separator]
  end

  def list_children referent, do_tag=true
    ("Children: "+
        (referent.child_tags.collect { |tag|
          (do_tag ? homelink(tag) : tag.name)+
              "(id #{tag.id.to_s})"
        }.join(', ') || "none")).html_safe
  end

end
