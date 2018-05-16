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
  [ :description, :title ]
  end

end