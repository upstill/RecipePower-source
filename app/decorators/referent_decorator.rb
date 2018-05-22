class ReferentDecorator < ModelDecorator
  include Templateer
  include DialogPanes
  delegate_all

  def title
    (tag = object.expression) ? tag.name : '** no tag **'
  end

  def human_name plural=false, capitalize=true
    object.class.to_s.sub /Referent/, ''
  end

  def dialog_pane_list
    @button_list ||= # A memoized list of buttons/panels to offer
        [
            (dialog_pane_spec(:description) if true),
            (dialog_pane_spec(:family) if true),
            (dialog_pane_spec(:expressions) if true),
            (dialog_pane_spec(:references) if true)
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
            references: {
                css_class: 'edit_page_refs',
                label: 'References',
                partial: 'pane_references'
            }
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
            pic: {
                css_class: :pic_picker,
                label: 'Picture',
                partial: 'pane_editpic'
            }
            comment: {
                css_class: :'comment-collectible',
                label: 'Comment',
                partial: 'pane_comment_collectible'
            },
=end
        }.each { |topic, value| value[:topic] = topic }
    @pane_specs[topic]
  end

  def visible_parent_tags
    parent_tags
  end

  def parent_tags_label
    'In Categories'
  end

  def visible_child_tags
    child_tags
  end

  def child_tags_label
    "Kinds of #{name}"
  end

  def visible_related_tags
    related_tags
  end

  def related_tags_label
    'See Also'
  end

end
