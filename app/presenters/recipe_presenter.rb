class RecipePresenter < CollectiblePresenter

  # Show the avatar on a recipe card only if there's direct image data (i.e., no fallback)
  def card_show_avatar
    decorator.imgdata.present?
  end

  def card_aspect which
    label = nil
    content =
    case which
      when :found_by
        if collector = decorator.first_collector
          h.labelled_avatar collector.decorate
        end
      when :description
        label = '' # Unlabelled
        @object.description
      when :notes
        @object.notes
      else
        return super
    end
    [ label, content ]
  end

end
