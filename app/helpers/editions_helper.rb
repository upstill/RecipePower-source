# Display one item from a Newsletter
module EditionsHelper

  # Render the item with 'editions/message_item', properly parametrized.
  # A link to the item goes through CollectibleController#touch, which
  # registers the view before redirecting to the item itself.
  def show_edition_item item, headline, before_text, after_text
    if item
      touch_params = { user_id: @touch_id }
      # Recipes, sites and feed entries redirect to the original item.
      # Other entities are internal to RecipePower, so go there.
      touch_params[:redirect_external] = true if [Recipe, Site, FeedEntry].include? item.class
      render 'editions/message_item',
             headline: headline,
             decorator: item.decorate,
             before_text: before_text,
             item_link: polymorphic_url([:touch, polymorphable(item)], touch_params),
             after_text: after_text
    end
  end
end
