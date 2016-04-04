class RecipePresenter < CollectiblePresenter

  # Show the avatar on a recipe card only if there's direct image data (i.e., no fallback)
  def card_show_avatar
    decorator.imgdata.present?
  end

  def card_video
    @vidlink ||=
    if decorator.url.present? &&
        (url = URI(decorator.url)) &&
        url.host.match(/\.youtube.com/) &&
        (vidlink = YouTubeAddy.extract_video_id(decorator.url))

      video_embed "https://www.youtube.com/embed/#{vidlink}"
    end || ''
  end

end
