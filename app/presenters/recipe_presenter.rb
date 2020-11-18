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

  # Present the recipe's content in its entirety.
  # THIS SHOULD HANDLED CAREFULLY b/c who knows what nefarious HTML it contains?
  def html_content
    # Handle empty content first by returning an error message
    if @object.content.blank?
      if @object.page_ref&.trimmed_content.blank?
        return "No Recipe content (PageRef content is empty)".html_safe
      elsif @object.recipe_page&.selected_content(@object.anchor_path, @object.focus_path).blank?
        return "No Recipe content (PageRef has content but RecipePage content is empty)".html_safe
      else
        return "Recipe has no content currently. Try Refreshing."
      end
    end
    hc = with_format('html') { render 'recipes/formatted_content', presenter: self }
    if response_service.admin_view?
      hc + content_tag(:h2, 'Raw Parsed Content -------------------------------') + @object.content.html_safe
    end
  end

  def content_for selector
    return if @object.content.blank?
    @nkdoc ||= Nokogiri::HTML.fragment @object.content
    case selector
    when :rp_title
    when :rp_author
    when :rp_yield, :rp_serves
    when :rp_prep_time, :rp_cook_time, :rp_total_time, :rp_time
    when :rp_ing_comment
    when :rp_inglist
    when :rp_instructions
    end
  end

end
