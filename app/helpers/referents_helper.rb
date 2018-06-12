module ReferentsHelper

=begin
  def referent_homelink ref, options={}
    homelink ref.becomes(Referent), options
  end
=end

  def summarize_ref_name referent, long=false
    extra = long ? ' going by the name of ' : ' '
    referent.typename.html_safe +
        extra.html_safe +
        " '".html_safe +
        referent.name.html_safe +
        "' ".html_safe
  end

  def summarize_referent ref, options={}
    ttltag = options[:except] || ref.expression
    separator = options[:separator]
    if options[:disambiguate]
      header = 'Knowledge about '.html_safe + homelink(ref, title: (ttltag ? ttltag.name : '<unnamed>'))
      inward_separator = summary_separator separator # Indent further after the header
    else
      header = ''
      inward_separator = separator
    end
    if options[:header] || options[:label]
      header = safe_join([
                             (options[:label] || 'Meaning'),
                             homelink(ref.becomes(Referent))
                         ], ': '.html_safe,
      )
    end
    summarize_set header,
                  [
                      summarize_ref_expressions(ref, except: ttltag, separator: inward_separator),
                      summarize_ref_parents(ref, separator: inward_separator),
                      summarize_ref_children(ref, separator: inward_separator),
                      summarize_ref_affiliates(ref, separator: inward_separator)
                  ],
                  separator
  end

  def summarize_ref_expressions referent, options={}
    header = 'Other Expression'
    ct = referent.expressions.count
    header = labelled_quantity(ct, header) if ct > 1
    summarize_set header,
                  referent.expressions.includes(:tag).limit(8).collect { |expr|
                    homelink(expr.tag, nuke_button: ct > 1) unless expr.tag == options[:except]
                  }.compact,
                  options[:separator]
  end

  def summarize_ref_parents ref, options={}
    set = ref.parents.includes(:canonical_expression).limit(8).collect { |parent| homelink parent.becomes(Referent) }
    if set.present?
      unless label = options[:label]
        label = labelled_quantity(ref.parents.count, 'Belongs to the category').sub(/^\d+\s/, '')
      end
      safe_join [ label, safe_join(set, ' | '.html_safe) ], ': '.html_safe
      # summarize_set label, set, options[:separator]
    end
  end

  def summarize_ref_children ref, options={}
    summarize_set (options[:label] || 'Category includes'),
                  ref.children.includes(:canonical_expression).limit(8).collect { |child| homelink child.becomes(Referent) },
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
