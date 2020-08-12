class RecipePresenter < CollectiblePresenter

  # Show the avatar on a recipe card only if there's direct image data (i.e., no fallback)
  def card_show_avatar
    decorator.imgdata.present?
  end

  def card_video
    @vidlink ||=
    if decorator.url.present? &&
        (url = URI(decorator.url)) &&
        url.host &&
        url.host.match(/\.youtube.com/) &&
        (vidlink = YouTubeAddy.extract_video_id(decorator.url))

      video_embed "https://www.youtube.com/embed/#{vidlink}"
    end || ''
  end

  # Recipes don't have a ribbon on their card
  def ribbon
  end

  # Recipes don't have a tab on their card
  def card_label
  end

  # The recipe's avatar on a card can be either a video or a straight image
  def card_avatar options={}
    card_video.if_present || super
  end

  def card_aspects which_column=nil
    ([ :yield, :times ] + super).compact.uniq
  end

  def card_aspect which
    label = nil
    contents =
        case which.to_sym
          when :times
            label = 'Time'
            [ ("Prep: #{decorator.prep_time}" if decorator.prep_time.present?),
              ("Cooking: #{decorator.cook_time}" if decorator.cook_time.present?),
              ("Total: #{decorator.total_time}" if decorator.total_time.present?) ].compact.join('</br>').html_safe
          when :yield
            label = 'Yield'
            decorator.yield if decorator.yield.present?
          else
            return super
        end
    [ label, contents ]
  end

  def html_content variant=nil
    # If the recipe hasn't yet been parsed, fall back on the recipe_page or page_ref for presentation
    @object.content.if_present ||
    if pr = @object.page_ref
      pr.recipe_page&.selected_content(@object.anchor_path, @object.focus_path) || # Presumably this is pre-trimmed
          present(pr).massaged_content
    end
  end

end
