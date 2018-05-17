# This module provides Pane functionality for editing dialogs
module DialogPanes

  # Provide a list of the editing panes available for the object
  def dialog_pane_list
    @button_list ||= # A memoized list of buttons/panels to offer
    [
      (dialog_pane_spec(:comment) if object.is_a?(Collectible)),
      (dialog_pane_spec(:edit) if user_can?(:admin)),
      (dialog_pane_spec(:tags) if object.is_a?(Taggable) && user_can?(:tag)),
      (dialog_pane_spec(:lists) if object.is_a?(Taggable) && user_can?(:lists)),
      (dialog_pane_spec(:pic) if object.is_a?(Picable) && user_can?(:editpic))
    ]
  end

  def dialog_has_pane topic
    dialog_pane_list.find { |spec| spec[:topic] == topic}
  end

  def dialog_pane_spec topic
    @pane_specs ||=
    {
        comment: {
            css_class: :'comment-collectible',
            label: 'Comment',
            partial: 'pane_comment_collectible'
        },
        edit: {
            css_class: :"edit_#{object.class.to_s.downcase}",
            label: 'Title & Description',
            partial: 'pane_edit'
        },
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
    }.each { |topic, value| value[:topic] = topic }
    @pane_specs[topic]
  end

end