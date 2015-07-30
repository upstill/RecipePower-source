class RecipePresenter < CollectiblePresenter

  def card_homelink options={}
    (data = (options[:data] || {}))[:report] = h.polymorphic_path [:touch, @decorator.object]
    link_to( @decorator.title,
             @decorator.url,
             options.merge(data: data)) + '&nbsp;'.html_safe +
        link_to( "",
                 @decorator.url,
                 class: 'glyphicon glyphicon-play-circle',
                 style: 'color: #aaa',
                 :target => '_blank')
    # link_to_submit @decorator.title, @decorator.object, options.merge(:mode => :partial, :data => data)
  end

  # Show the avatar on a recipe card only if there's direct image data (i.e., no fallback)
  def card_show_avatar
    decorator.imgdata.present?
  end

end
