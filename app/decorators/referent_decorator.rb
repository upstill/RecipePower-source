class ReferentDecorator < CollectibleDecorator
  include Templateer
  include DialogPanes
  delegate_all

  def title
    (tag = object.expression) ? tag.name : '** no tag **'
  end

  def human_name plural=false, capitalize=true
    object.class.to_s.sub /Referent/, ''
  end

  # Enumerate all the pictures connected with this referent and apply the method to each until a non-nil result is found
  def first_from_pix method
    @object.send(method) ||
        @object.image_references.to_a.find { |ir| ir.send(method) } ||
        @object.page_refs.includes(:picture).where.not(picture_id: nil).map(&(method)).compact.first ||
        PageRef.includes(:picture).tagged_by(@object.tag_ids).where.not(picture_id: nil).map(&(method)).compact.first
  end

  # A referent gets its picture from either 1) a directly-associated ImageReference, or an image
  # from one of its PageRefs
  def picdata
    first_from_pix :imgdata
  end

  # For situations in which a data URL won't do, get an image link
  def picurl
    first_from_pix :imgurl
  end

  # Provide the PageRef's associated with a referent. These come directly from Referments,
  # and indirectly via taggings on any of the referent's tags
  def page_refs kind=nil
    kind_int = PageRef.kinds[kind]
    (@object.page_refs.where(kind: kind_int).to_a +
     PageRef.tagged_by(@object.tag_ids).where(kind: kind_int).to_a).uniq
  end

  # Provide the set of entities of a given type that are acquired either:
  # -- directly, via the Referments, or
  # -- indirectly, via taggings on the Referent's expressions
  def tagged_entities type, who=nil
    entity_ids = Tagging.where(entity_type: type.camelize, tag_id: tag_ids).pluck :entity_id
    case type.to_sym
      when :list
        return List.where(id: entity_ids).to_a
      when :feed
        return Feed.where(id: entity_ids).to_a
      when :recipe
        return @object.recipes # Recipe.where(id: @object.referments.where(referee_type: 'Recipe').pluck :referee_id)
      when :site
        entity_ids += @object.page_refs.where(kind: PageRef.kinds[:site]).pluck :site_id
        Site.includes(:page_ref).where(id: entity_ids).to_a
      else
        PageRef.where(kind: PageRef.kinds[type], id: entity_ids)
    end
  end

  def dialog_pane_list topic=nil
    @button_list ||= # A memoized list of buttons/panels to offer
        [
            (dialog_pane_spec(:description) if true),
            (dialog_pane_spec(:family) if true),
            (dialog_pane_spec(:expressions) if true),
            (dialog_pane_spec(:referments) if true),
            (dialog_pane_spec(:pic) if true)
        ].compact
  end

  def dialog_pane_spec topic
    @pane_specs ||=
        {
            description: {
                css_class: :"edit_#{object.class.base_class.to_s.downcase}",
                label: 'Description',
                partial: 'pane_description'
            },
            family: {
                css_class: 'edit_family',
                label: 'Family',
                partial: 'pane_family'
            },
            expressions: {
                css_class: 'edit_expressions',
                label: 'Expressions',
                partial: 'pane_expressions'
            },
            referments: {
                css_class: 'edit_referments',
                label: 'References',
                partial: 'pane_referments'
            },
=begin
            tags: {
                css_class: :'tag-collectible',
                label: 'Tags',
                partial: 'pane_tag'
            },
            lists: {
                css_class: :lists_collectible,
                label: 'Treasuries',
                partial: 'pane_lists_collectible'
            },
=end
            pic: {
                css_class: :pic_picker,
                label: 'Picture',
                partial: 'pane_editpic'
            },
            comment: {
                css_class: :'comment-collectible',
                label: 'Comment',
                partial: 'pane_comment_collectible'
            }
        }.each { |topic, value| value[:topic] = topic }
    @pane_specs[topic]
  end

  # Return a list of tags and a label for the collection
  # TODO: these should be the tags visible to the given user, not all tags
  def visible_tags_of_kind kind, viewer=nil
    case kind
      when :parents
        parent_tags
      when :children
        child_tags
      when :relateds
        related_tags
      when :expressions
        tags
      when :synonyms
        tags.where.not id: tag_id
    end
  end

end
