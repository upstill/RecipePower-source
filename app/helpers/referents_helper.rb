module ReferentsHelper

  def referent_homelink ref, options={}
    homelink ref.becomes(Referent), options
  end

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
                             referent_homelink(ref)
                         ], ': '.html_safe,
      )
      inward_separator = summary_separator separator
    end
    summarize_set '',
                  [
                      header,
                      summarize_ref_expressions(ref, separator: inward_separator),
                      summarize_ref_parents(ref, separator: inward_separator),
                      summarize_ref_children(ref, separator: inward_separator)
                  ],
                  separator
  end

  def summarize_ref_expressions referent, options={}
    summarize_set labelled_quantity(referent.expressions.count, 'Expression'),
                  referent.expressions.collect { |expr|
                    tag_homelink(expr.tag, nuke_button: referent.expressions.count > 1)
                  },
                  options[:separator]
  end

  def summarize_ref_parents ref, options={}
    summarize_set (options[:label] || 'Categorized under'),
                  ref.parents.collect { |parent| referent_homelink parent.becomes(Referent) },
                  options[:separator]
  end

  def summarize_ref_children ref, options={}
    summarize_set (options[:label] || 'Category includes'),
                  ref.children.collect { |child| referent_homelink child.becomes(Referent) },
                  options[:separator]
  end

  def list_children referent, do_tag=true
    ("Children: "+
        (referent.child_tags.collect { |tag|
          (do_tag ? tag_homelink(tag) : tag.name)+
              "(id #{tag.id.to_s})"
        }.join(', ') || "none")).html_safe
  end

end
