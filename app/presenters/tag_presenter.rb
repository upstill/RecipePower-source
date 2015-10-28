class TagPresenter < BasePresenter
  include CardPresentation
  presents :tag
  delegate :name, to: :tag

  def tagserv
    @tagserv ||= TagServices.new tag
  end

  def card_avatar?
    false
  end

  # Present the user's avatar, optionally with a form for uploading the image (if they're the viewer)
  def card_avatar options={}
    nil
  end

  def card_homelink options={}
    tag_homelink tag, options
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

  def card_aspects which_column
    [
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
        ],
    ][which_column]
  end

  def card_aspect which
    label = content = nil
    itemstrs = []
    case which
      when :tag_synonyms
        label = 'synonyms'
        itemstrs = tagserv.synonyms.collect { |tag| h.tag_homelink tag }
      when :meaning
        label = 'described as'
        # content = h.summarize_meaning
        if (meaning = tagserv.primary_meaning) && meaning.description.present?
          content = meaning.description
        end
      when :tag_owners
        label = 'private to'
        # content = h.summarize_tag_owners
        itemstrs = tagserv.owners.collect { |owner| h.user_homelink owner } unless tagserv.isGlobal
      when :tag_similars
        label = 'similar tags'
        # content = h.summarize_tag_similars
        # TODO: The elimination should be done in the query
        itemstrs = Tag.where(normalized_name: tagserv.normalized_name).
            to_a.
            delete_if { |other|
              other.id == tagserv.id
            }.
            collect { |other|
              # h.summarize_tag_similar other, (args[:absorb_btn] && tagserv.can_absorb(other))
              tagidstr = other.id.to_s
              link = h.tag_homelink other
              link = link + link_to_submit( "Absorb",
                                      "tags/#{other.id.to_s}/absorb?victim=#{tagidstr}",
                                      class: "absorb_button",
                                      id: "absorb_button_#{tagidstr}") if tagserv.can_absorb(other)
              content_tag :span,
                          link,
                          class: 'absorb_'+tagidstr
            }
      when :tag_referents
        label = 'meanings'
        # content = h.summarize_tag_referents
        itemstrs =
            tagserv.
            referents.
            to_a.
            collect { |ref|
              # summarize_referent ref, "Other Meaning(s)"
              h.referent_homelink ref if ref != tagserv.primary_meaning
            }.compact
      when :tag_parents
        label = 'under categories'
        # content = h.summarize_tag_parents
        itemstrs = tagserv.parents.collect { |parent| h.tag_homelink parent }
      when :tag_children
        label = 'includes'
        # content = h.summarize_tag_children
        itemstrs = tagserv.children.collect { |child| h.tag_homelink child }
      when :tag_references
        label = 'references'
        # content = h.summarize_tag_references
        itemstrs = tagserv.references.collect{ |reference| h.present_reference(reference) }
      when :tag_relations
        label = 'See Also'
        # content = h.summarize_tag_relations
        itemstrs = Referent.related(tagserv, false, true).collect { |rel|
          if(rel.id != tagserv.id)
            ts = TagServices.new(rel)
            refs = ts.references
            refstrs = refs.collect{ |reference| present_reference(reference) }
            content_tag(:div,
                        tag_info_section(refstrs, label: ("'#{rel.synonyms.map(&:name).join('/&#8201')}'" + " on ")).html_safe,
                        class: "container").html_safe unless refstrs.empty?
          end
        }.compact
    end
    content = itemstrs.join(', ') unless itemstrs.empty?
    [label, content]
  end

  def show_or_edit which, val
    if is_viewer?
      if val.present?
        (user.about + link_to_submit("Edit", edit_user_path(section: which), button_size: "xs")).html_safe
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

  private

  def handle_none(value)
    if value.present?
      yield
    else
      h.content_tag :span, "None given", class: "none"
    end
  end

end
