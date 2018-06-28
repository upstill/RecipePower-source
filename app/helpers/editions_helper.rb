module EditionsHelper

  def show_edition_item item, headline, before_text, after_text
    if item
      render 'message_item',
             headline: headline,
             item: item,
             before_text: before_text,
             after_text: after_text
    end
  end
end
