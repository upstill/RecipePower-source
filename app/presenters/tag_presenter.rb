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

  def table_summaries tagserv, admin_on
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

  def synonyms label='Synonyms: ', options={}
    if label.is_a?(Hash)
      label, options = 'Synonyms: ', label
    end
    # The synonyms are the other expressions of this tag's referents
    return if (syns = tagserv.synonyms).empty?
    synstrs = syns.collect { |syn| # h.tag_homelink syn
      similar syn, (options[:absorb_btn] && tagserv.can_absorb(syn))
    }.join('<br>').html_safe
    # info_section synstrs, label: label, joinstr: '<br>'
  end

  # Helper for showing the tags which are potentially redundant wrt. this tag:
  # They match in the normalized_name field
  def similars args={}
    others = tagserv.lexical_similars
    label= args[:label] || 'Similar tags: '
    joiner = args[:joiner] || ' '
    ("<span>#{label}"+
        others.collect { |other| similar other, (args[:absorb_btn] && tagserv.can_absorb(other)) }.join(joiner)+
        "</span>").html_safe
    # info_section others.collect { |other| summarize_tag_similar other, (args[:absorb_btn] && tagserv.can_absorb(other)) }, label: label, joinstr: joiner
  end
  
  def meaning
    if (meaning = tagserv.primary_meaning) && !meaning.description.blank?
      "<p class=\"airy\"><strong>...described as</strong> '#{tagserv.primary_meaning.description}'</p>".html_safe
    end
  end

  def owners
    return if tagserv.isGlobal || (owners = tagserv.owners).empty?
    ownerstrs = owners.collect { |owner| owner.handle }
    info_section ownerstrs, label: '...private to '
  end
  
  def parents label = "Categorized Under: "
    info_section tagserv.parents.collect { |parent| h.tag_homelink parent }, label: label
  end

  def children label = "Examples: "
    info_section tagserv.children.collect { |child| h.tag_homelink child }, label: label
  end

  def referents
    info_section(
        tagserv.referents.to_a.keep_if { |ref| ref != tagserv.primary_meaning }.each { |ref|
          h.summarize_referent ref, label: "Other Meaning(s)"
        }, label: "Referents: ")
  end

  # Return HTML for the links associated with this tag
  def references label = "See "
    unless (refstrs = definitions).empty?
      (h.content_tag( :h3, "References")+
          h.content_tag( :div,
                       info_section( refstrs, label: (label + "'#{tagserv.name}'" + " on ") ).html_safe,
                       class: "container")).html_safe
    end
  end

  def definitions ts=tagserv
    # tagserv.references.where(canonical: true, type: 'DefinitionReference').collect{ |reference| present_reference(reference) }.compact
    ts.definition_page_refs.collect { |definition| h.present_definition(definition) }.compact
  end

  # Return HTML for the links related to a given tag (i.e., the links for 
  # all tags related to this one)
  def relations label = 'See Also'
    links =
        Referent.related(tag, false, true).collect { |rel|
            refstrs = definitions(TagServices.new rel)
            h.content_tag(:div,
                        info_section(refstrs, label: ("'#{rel.synonyms.map(&:name).join('/&#8201')}'" + " on ")).html_safe,
                        class: "container").html_safe unless refstrs.empty?
        }.compact.join(' | ')
    (h.content_tag(:h3, label)+links.html_safe) if links
  end

  # Currently unused
  def recipes header="<h4>Used as Tag on Recipe(s)</h4>"
    recipes =
        tagserv.recipes(true).uniq.collect { |rcp|
          h.content_tag :li, "#{link_to rcp.title, rcp.url} #{h.collectible_info_icon rcp.decorate}".html_safe, class: "tog_info_rcp_title"
        }
    unless recipes.empty?
      ("#{header}<ul>"+recipes.join('<br>')+"</ul>").html_safe
    end
  end

  # Present one section of the tag info using a label, a (possibly empty) collection
  # of descriptive strings, and a classname for a span summarizing the section (presumably
  # because the individual entries are meant to show on a line).
  # If the collection is empty, we return nil; if the contentclass is blank we don't wrap it in a span
  def info_section contentstrs, options
    contentclass = options[:contentclass] || "tag_info_section_content"
    label = options[:label] || ""
    joinstr = options[:joinstr] || ", "
    if contentstrs && !contentstrs.empty?
      contentstr = contentclass.blank? ?
          contentstrs.join('').html_safe :
          h.content_tag(:span, contentstrs.join(joinstr).html_safe, class: contentclass)
      # h.content_tag( :div,
      #   (label+contentstr).html_safe,
      #  class: "info_section"
      # )
      result =
          h.content_tag :div,
                      h.content_tag( :div,
                                   h.content_tag(:p, "<strong>#{label}</strong>".html_safe, class: "pull-right"),
                                   class: "col-md-4")+
                          h.content_tag( :div,
                                       h.content_tag(:p, contentstr.html_safe, class: "pull-left"),
                                       class: "col-md-8"),
                      class: "row"
      result.html_safe
    end
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

  def card_aspects which_column=nil
    [
        :tag_synonyms,
        :meaning,
        :tag_owners,
        :tag_similars,
        :tag_referents,
        :tag_parents,
        :tag_children,
        :tag_references,
        :tag_relations,
    ]
  end

  def card_aspect which
    label = content = nil
    itemstrs =
    (case which
       when :description
         return ['', "#{decorator.typename.match(/^[aeiou]/i) ? 'An' : 'A'} #{decorator.typename} tag"]
       when :tag_synonyms
        label = 'synonyms'
        tagserv.synonyms.collect { |tag| h.tag_homelink tag }
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
        definitions(tagserv)
      when :tag_relations
        label = 'See Also'
        # content = h.summarize_tag_relations
        Referent.related(tagserv, false, true).collect { |rel|
          definitions(TagServices.new rel) if(rel.id != tagserv.id)
        }.compact.flatten
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
