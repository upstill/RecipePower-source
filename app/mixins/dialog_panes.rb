# This module provides Pane functionality for editing dialogs on Collectible objects
module DialogPanes
  include Pundit

  # Provide a list of the editing panes available for the object
  def dialog_pane_list topics=nil # A comma-separated list of topics to edit
    return @button_list if @button_list
    @button_list = # A memoized list of buttons/panels to offer
    [
      (dialog_pane_spec(:comment) if object.is_a?(Collectible)),
      (dialog_pane_spec(:edit) if Pundit.policy(User.current, object).edit?),
      (dialog_pane_spec(:tags) if Pundit.policy(User.current, object).tag?),
      (dialog_pane_spec(:lists) if Pundit.policy(User.current, object).lists?),
      (dialog_pane_spec(:pic) if Pundit.policy(User.current, object).editpic?),
      (dialog_pane_spec( :site) if object.respond_to?(:site) && Pundit.policy(User.current, object.site).edit?)
    ].compact
    if topics
      topics = topics.split(',').map &:to_sym
      @button_list.keep_if { |button| topics.include? button[:topic] }
    end
    @button_list
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
        },
        site: {
            css_class: :site_trimmers,
            label: 'Site',
            partial: 'pane_editsite'
        }
    }.each { |topic, value| value[:topic] = topic }
    @pane_specs[topic]
  end

end
