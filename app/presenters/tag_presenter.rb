class TagPresenter < BasePresenter
  include CardPresentation
  presents :tag

  def tagserv
    tagserv ||= TagServices.new tag
  end

  def name withtype = false, do_link = true
    ((withtype ? "<i>#{decorator.typename}</i> " : '' )+
        "'<strong>#{do_link ? h.tag_homelink(tag) : tag.name}</strong>'").html_safe
  end

  def table_summaries admin_view_on
    # set = [ self.recipes_summary, self.owners, self.children, self.referents, self.references, self.relations ]
    set = self.taggees_table_summary
    set << self.owners_summary(limit: 5) do |ownerstrs, options|
      h.format_table_summary ownerstrs, labelled_quantity(options[:count] || ownerstrs.count, 'owner')
    end
    set << self.parents_summary do |scope, options|
      h.format_table_summary scope.limit(5).collect { |tag| h.tag_homelink entity },
                             labelled_quantity(scope.count, 'parent')
    end
    set << self.children_summary do |scope, options|
      h.format_table_summary scope.limit(5).collect { |tag| h.tag_homelink entity },
                             labelled_quantity(scope.count, 'child')
    end
    set << self.referents_summary do |scope, options|
      h.format_table_summary scope.limit(5).collect { |entity| h.tag_homelink entity },
                             labelled_quantity(scope.count, 'definition')
    end
    set << self.references_summary do |scope, options|
      h.format_table_summary scope.collect { |definition| h.present_definition(definition) }.compact,
                             labelled_quantity(scope.count, 'reference')
    end
    summarize_set '', set
    # summarize_tag_owners
    ## summarize_tag_similars
    # summarize_tag_parents
    # summarize_tag_children
    # summarize_tag_referents
    # summarize_tag_recipes
    # summarize_tag_references
    ## summarize_tag_definitions
    # summarize_tag_relations
    ## summarize_tag_synonyms
  end

  def synonyms_summary options={}
    label = options[:label] ||'Synonyms: '
    # The synonyms are the other expressions of this tag's referents
    return if (syns = tagserv.synonyms true).empty?
    syns = syns.limit(options[:limit]) if options[:limit]
    synlinks = syns.collect { |syn| # h.tag_homelink syn
      h.summarize_tag_similar tag, syn, (options[:absorb_btn] && tagserv.can_absorb(syn))
    }
    if block_given?
      yield synlinks, label
    else
      h.safe_join synlinks, '<br>'
    end
  end

  # Helper for showing the tags which are potentially redundant wrt. this tag:
  # They match in the normalized_name field
  def similars_summary options={}
    return unless (others = tagserv.lexical_similars).present?
    label = options[:label] || 'Similar tag'
    simlinks = others.collect { |other| h.summarize_tag_similar tag, other, (options[:absorb_btn] && tagserv.can_absorb(other)) }
    if block_given?
      yield simlinks, label
    else
      simlinks.unshift(label) unless label.blank?
      h.safe_join simlinks, (options[:joiner] || ' ')
    end
  end

  def meaning
    if (meaning = tagserv.primary_meaning) && !meaning.description.blank?
      "<p class=\"airy\"><strong>...described as</strong> '#{tagserv.primary_meaning.description}'</p>".html_safe
    end
  end

=begin
  def owners options = {}
    return if tagserv.isGlobal || (scope = tagserv.owners).empty?
    h.format_card_summary scope.collect { |owner| owner.handle }, label: '...private to '
  end
=end

  def owners_summary options = {}
    return if tagserv.isGlobal || (scope = tagserv.owners).empty?
    scope = scope.limit(options[:limit]) if options[:limit]
    ownerstrs = scope.collect { |owner| h.homelink owner }
    if block_given?
      yield ownerstrs, options
    else
      h.format_card_summary ownerstrs, { label: '...private to ' }.merge(options)
    end
  end

=begin
  def parents options={}
    label = options[:label] || "Categorized Under: "
    unique= options[:unique] || true
    return if (scope = tagserv.parents(unique)).empty?
    h.format_card_summary scope.collect { |parent| h.tag_homelink parent }, label: label
  end
=end

  def parents_summary options={}
    label = options[:label] || 'Categorized Under: '
    unique = options[:unique] || false
    return if (scope = tagserv.parents(unique)).empty?
    if block_given?
      yield scope, options
    else
      h.format_card_summary scope.collect { |parent| h.tag_homelink parent }, label: label
    end
  end

=begin
  def children options={}
    label = options[:label] || 'Category Includes: '
    unique = options[:unique] || true
    h.format_card_summary tagserv.children(unique).collect { |child| h.tag_homelink child }, label: label
  end
=end

  def children_summary options={}
    label = options[:label] || 'Category Includes: '
    unique = options[:unique] || true
    return if (scope = tagserv.children(unique)).empty?
    if block_given?
      yield scope, options
    else
      h.format_card_summary scope.collect { |child| h.tag_homelink child }, label: label
    end
  end

=begin
  def referents options={}
    unique = options[:unique] || true
    label = options[:label] || (unique ? 'Other Meaning(s)' : 'All Meaning(s)')
    h.format_card_summary(
        tagserv.referents(unique).collect { |ref| h.summarize_referent ref, label: label },
        label: 'Referents: ')
  end
=end

  def referents_summary options={}
    unique = options[:unique] || true
    label = options[:label] || (unique ? 'Other Meaning(s)' : 'All Meaning(s)')
    return if (scope = tagserv.referents(unique)).empty?
    h.format_card_summary(
        scope.collect { |ref| h.summarize_referent ref, label: label },
        label: label)
  end

=begin
  # Return HTML for the links associated with this tag
  def references options={}
    label = options[:label] || 'See '
    refstrs = ts.definition_page_refs.collect { |definition| h.present_definition(definition) }.compact
    unless refstrs.empty?
      (h.content_tag( :h3, "References")+
          h.content_tag( :div,
                       h.format_card_summary( refstrs, label: (label + "'#{tagserv.name}'" + " on ") ).html_safe,
                       class: "container")).html_safe
    end
  end
=end

  def references_summary options={}
    label = options[:label] || 'See '
    return if (scope = tagserv.definition_page_refs).empty?
    if block_given?
      yield scope, options
    else
      refstrs = scope.collect { |definition| h.present_definition(definition) }.compact
      (h.content_tag(:h3, "References")+
          h.content_tag( :div,
                         h.format_card_summary( refstrs, label: (label + "'#{tagserv.name}'" + " on ") ).html_safe,
                         class: "container")).html_safe
    end
  end

=begin
  def definitions ts=tagserv
    # tagserv.references.where(canonical: true, type: 'DefinitionReference').collect{ |reference| present_reference(reference) }.compact
    ts.definition_page_refs.collect { |definition| h.present_definition(definition) }.compact
  end

NB: The relations method has no information not provided by
  # Return HTML for the links related to a given tag (i.e., the links for
  # all tags related to this one)
  def relations options={}
    label = options[:label] || 'See Also'
    links =
        Referent.related(tag, false, true).collect { |rel|
          refstrs = definitions(TagServices.new rel)
          h.content_tag(:div,
                        h.format_card_summary(refstrs, label: ("'#{rel.synonyms.map(&:name).join('/&#8201')}'" + " on ")).html_safe,
                        class: "container").html_safe unless refstrs.empty?
        }.compact.join(' | ')
    (h.content_tag(:h3, label)+links.html_safe) if links
  end

  def relations_summary options={}
    return if (scope = Referent.related(tag, false, true)).empty?
    if block_given?
      yield scope, options
    else
      links =
          Referent.related(tag, false, true).collect { |rel|
            refstrs = definitions(TagServices.new rel)
            h.content_tag(:div,
                          h.format_card_summary(refstrs, label: ("'#{rel.synonyms.map(&:name).join('/&#8201')}'" + " on ")).html_safe,
                          class: "container").html_safe unless refstrs.empty?
          }.compact.join(' | ')
      # (h.content_tag(:h3, label)+links.html_safe) if links.present?
      h.format_card_summary links, { label: 'See Also' }.merge(options)
    end
  end

  def recipes label="<h4>Used as Tag on Cookmarks(s)</h4>"
    return if (scope = tagserv.recipes).empty?
    recipes =
        tagserv.recipes(true).uniq.collect { |rcp|
          h.content_tag :li, "#{link_to rcp.title, rcp.url} #{h.collectible_info_icon rcp.decorate}".html_safe, class: "tog_info_rcp_title"
        }
    unless recipes.empty?
      ("#{header}<ul>"+recipes.join('<br>')+"</ul>").html_safe
    end
  end

  def recipes_summary options={}
    separator = summary_separator options[:separator]
    inward_separator = summary_separator separator
    scope = tagserv.recipes
    safe_join ([labelled_quantity(scope.count, 'cookmark')] +
                  scope.limit(5).collect { |rcp| h.homelink rcp }
              ), inward_separator
  end
=end

  # The taggees of a tag are only summarized in its table listing;
  # when shown on a card, the taggees should appear in an associated list
  def taggees_table_summary options={}
    taggees = tagserv.taggees
    return (options[:report_null] ? ['No Cookmarks'] : []) if taggees.empty?
    taggees.collect { |keyval|
      klass, scope = *keyval
      label = labelled_quantity(scope.count, klass.model_name.singular)
      h.format_table_summary scope.limit(5).collect { |entity| h.homelink entity }, label, options
    }
  end

  def card_homelink options={}
    h.tag_homelink tag, options
  end

  def is_viewer?
    @viewer && (@viewer.id == user.id)
  end

  def card_header_content
    name
  end

  def card_ncolumns
    1
  end

  # Report the aspects for a card on the tag
  # If a block is given, call it for each aspect
  def card_aspects which_column=nil
    aspects = [
        :tag_synonyms,
        :meaning,
        :tag_owners,
        :tag_similars,
        :tag_referents,
        :tag_parents,
        :tag_children,
        :tag_references,
    ]
    if block_given?
      aspects.each { |aspect|
        yield *presenter.card_aspect(aspect)
      }
    end
    aspects
  end

  def card_aspect which
    label = content = nil
    itemstrs =
    (case which
       when :description
         return ['', "... for tagging by #{decorator.typename}"]
       when :tag_synonyms
         label = 'synonyms'
         synonyms_summary do |synlinks, found_label|
           synlinks
         end
      when :meaning
        label = 'described as'
        # content = h.summarize_meaning
        if (meaning = tagserv.primary_meaning) && meaning.description.present?
          content = meaning.description
        end
        nil
      when :tag_owners
        label = 'private to'
        # content = h.summarize_tag_owners
        tagserv.owners.collect { |owner| h.user_homelink owner } unless tagserv.isGlobal
      when :tag_similars
        label = 'similar tags'
        # content = h.summarize_tag_similars
        # TODO: The elimination should be done in the query
        Tag.where(normalized_name: tagserv.normalized_name).
            to_a.
            delete_if { |other|
              other.id == tagserv.id
            }.
            collect { |other|
              # h.summarize_tag_similar other, (args[:absorb_btn] && tagserv.can_absorb(other))
              tagidstr = other.id.to_s
              link = h.tag_homelink other
              link = link + h.link_to_submit( "Absorb",
                                      "tags/#{other.id.to_s}/absorb?victim=#{tagidstr}",
                                      class: "absorb_button",
                                      id: "absorb_button_#{tagidstr}") if tagserv.can_absorb(other)
              h.content_tag :span,
                          link,
                          class: 'absorb_'+tagidstr
            }
      when :tag_referents
        label = 'meanings'
        # content = h.summarize_tag_referents
        tagserv.
        referents.
        to_a.
        collect { |ref|
          # summarize_referent ref, "Other Meaning(s)"
          h.referent_homelink ref if ref != tagserv.primary_meaning
        }
      when :tag_parents
        label = 'under categories'
        # content = h.summarize_tag_parents
        tagserv.parents.collect { |parent| h.tag_homelink parent }
      when :tag_children
        label = 'includes'
        # content = h.summarize_tag_children
        tagserv.children.collect { |child| h.tag_homelink child }
      when :tag_references
        label = 'references'
        # content = h.summarize_tag_references
        tagserv.definition_page_refs.collect { |definition| h.present_definition(definition) }.compact
=begin
      when :tag_relations
        label = 'See Also'
        # content = h.summarize_tag_relations
        Referent.related(tagserv, false, true).collect { |rel|
          definitions(TagServices.new rel) if(rel.id != tagserv.id)
        }.compact.flatten
=end
     end || []).compact
    content = safe_join(itemstrs, ', ') unless itemstrs.empty?
    [label, content]
  end

  # Does this presenter have an avatar to present on cards, etc?
  def card_avatar?
    tagserv.images.present?
  end

  def card_avatar options={}
    if image_ref = tagserv.images.first
      image_with_error_recovery image_ref.imgdata || image_ref.url
    end
  end

  def show_or_edit which, val
    if is_viewer?
      if val.present?
        (user.about + h.link_to_submit("Edit", edit_user_path(section: which), button_size: "xs")).html_safe
      else
        card_aspect_editor which
      end
    else
      val if val.present?
    end
  end

  def about
    handle_none user.about do
      markdown(user.about)
    end
  end

  def tags
    user.tags.collect { |tag| tag.name }.join(', ')
  end

  def tools_menu

  end

  private

  def handle_none(value)
    if value.present?
      yield
    else
      h.content_tag :span, "None given", class: "none"
    end
  end

end
