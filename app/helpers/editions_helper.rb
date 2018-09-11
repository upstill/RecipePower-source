module EditionsHelper

  # Provide a link to an item mentioned in the edition, according to its class
  def item_link decorator
    # Recipes and Sites link to the original, external page
    case decorator.object
      when Recipe, Site
        decorator.url
      when User
        collection_user_url decorator
      else
        # Any other item links to the internal card page
        polymorphic_link decorator, :absolute, action: :associated
    end
  end

  def show_edition_item item, headline, before_text, after_text
    if item
      decorator = item.decorate
      render 'editions/message_item',
             headline: headline,
             decorator: decorator,
             before_text: before_text,
             item_link: item_link(decorator),
             after_text: after_text
    end
  end
end
