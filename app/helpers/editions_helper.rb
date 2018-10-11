module EditionsHelper

  def show_edition_item item, headline, before_text, after_text
    if item
      item = item.becomes item.class.base_class
      decorator = item.decorate
      touch_params = { user_id: @touch_id }
      touch_params[:redirect_external] = true if [Recipe, Site, FeedEntry].include? item
      render 'editions/message_item',
             headline: headline,
             decorator: decorator,
             before_text: before_text,
             item_link: polymorphic_url([:touch, item], touch_params),
             after_text: after_text
    end
  end
end
