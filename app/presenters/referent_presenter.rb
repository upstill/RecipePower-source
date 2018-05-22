class ReferentPresenter < CollectiblePresenter
  include CardPresentation
  presents :referent

  def card_avatar_column
=begin
  content_tag :div,
              (content_tag(:div, card_avatar(onlinks: true)+tag(:br, style: 'clear: both'), class: 'avatar') +
                  content_tag(:div, (card_avatar_accompaniment || ''.html_safe)+tag(:br, style: 'clear: both'), class: 'found-by') +
                  tag(:br, style: 'clear: both')),
              class: 'stamp card-column flexor avatar-column'
=end
  end

  def card_aspects which_column=nil
    # decorator.object.is_a?(Taggable) ? decorator.individual_tagtypes : []
  [ :description, :title, :parents, :children, :relateds ]
  end

  def card_aspect which
    label = nil
    whichsym = which.to_sym
    whichstr = which.to_s.downcase.singularize
    contents =
        case whichsym
          when :parents, :children, :relateds
            denotation = which.to_s.downcase.singularize
            tags = decorator.send "visible_#{whichstr}_tags" # visible_tags :tagtype => :Dish
            label = decorator.send("#{whichstr}_tags_label")
            label = field_label_counted label, tags.count unless whichsym == :relateds
            entity_links tags, joinstr: ' | '
          else
            return super
        end
    [ label, contents ]
  end

end