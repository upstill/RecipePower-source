require 'scraping/parser.rb'
module RecipeContentsHelper
  def recipe_content recipe_or_decorator
    decorator = recipe_or_decorator.is_a?(Draper::Decorator) ? recipe_or_decorator : recipe_or_decorator.decorate
    with_format('html') { render 'collectible/show_contents', decorator: decorator, presenter: present(decorator) }
  end

  def recipe_content_replacement recipe_or_decorator
    [ 'div.card-content', recipe_content(recipe_or_decorator) ]
  end

  # Assert an annotation button in the recipe_contents editor. Give it a title, and declare its token for submission
  def annotation_button token, options={}
    dialog_submit_button Parser.token_to_title(token),
                         options.merge(data: {'recipe[recipe_contents][token]' => token},
                                       class: "#{options[:class]} submit-selection",
                                       button_style: 'default')
  end
end
