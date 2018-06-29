module ReferentsHelper

  def summarize_ref_name referent, long=false
    extra = long ? ' going by the name of ' : ' '
    referent.typename.html_safe +
        extra.html_safe +
        " '".html_safe +
        homelink(referent) +
        "' ".html_safe
  end

  def summarize_referent ref, options={}
    format_table_tree referent_summary(ref, options)
  end

  def referent_identifier ref, label=nil
    safe_join [ (label.if_present || ref.model_name.human.split(' ').first),
                homelink(ref) ], ': '.html_safe
  end

  def referent_summary ref, options={}
    ttltag = options[:except] || ref.expression
    header =
        options[:disambiguate] ?
          'Knowledge about '.html_safe + homelink(ref, title: (ttltag ? ttltag.name : '<unnamed>')) :
          ''.html_safe

    header = referent_identifier(ref, options[:label]) if options[:header] || options[:label]
    sub_summs = [
        ref_expressions_summary(ref, except: ttltag),
        ref_parents_summary(ref),
        ref_children_summary(ref),
        ref_affiliates_summary(ref)
    ].compact.flatten(1)
    if sub_summs.present?
      header.present? ? [ header, sub_summs ] : sub_summs
    end
  end

  def ref_expressions_summary referent, options={}
    ct = referent.expressions.count
    summs = referent.expressions.includes(:tag).limit(8).collect { |expr|
      homelink(expr.tag, nuke_button: ct > 1) unless expr.tag == options[:except]
    }.compact
    if summs.present?
      header = 'Synonym'.html_safe
      (ct = summs.count) > 1 ? [labelled_quantity(ct, header), summs] : (header + ': '.html_safe + summs.first)
    end
  end

  def ref_parents_summary ref, options={}
    set = ref.parents.includes(:canonical_expression).limit(8).collect { |parent| homelink parent }
    if set.present?
      label = (options[:label].if_present || ('Belongs to the categor'+(set.count > 1 ? 'ies' : 'y '))).html_safe
      set.count > 1 ? [ label, set ] : (label + set.first)
    end
  end

  def ref_children_summary ref, options={}
    child_summs = ref.children.includes(:canonical_expression).limit(8).collect { |child| homelink child }
    if child_summs.present?
      label = (options[:label].if_present || 'Category includes ').html_safe
      child_summs.count > 1 ? [label, child_summs] : (label+child_summs.first)
    end
  end

  def ref_affiliates_summary ref, options={}
    affiliate_summs =
        ref.affiliates.collect { |affil|
          case affil
            when Referent
              referent_identifier affil
            when PageRef
              present_page_ref affil, options.merge(label: 'About') # affil.model_name.human.sub(/ ref$/,''))
            else
              safe_join [affil.model_name.human.split(' ').first.html_safe, homelink(affil)], ': '
          end
        }.compact.flatten(1)

    if affiliate_summs.present?
      label = (options[:label] || 'Associated with ').html_safe
      affiliate_summs.count > 1 ? [ label, affiliate_summs ] : (label+affiliate_summs.first)
    end
  end

end
