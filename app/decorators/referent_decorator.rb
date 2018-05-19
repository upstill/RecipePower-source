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
                css_class: :"edit_#{object.class.to_s.downcase}",
                label: 'Description',
                partial: 'pane_description'
            },
            family: {
                css_class: 'family_pane',
                label: 'Family',
                partial: 'pane_family'
            },
            expressions: {
                css_class: 'expressions_pane',
                label: 'Expressions',
                partial: 'pane_expressions'
            },
            references: {
                css_class: 'references_pane',
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
end
