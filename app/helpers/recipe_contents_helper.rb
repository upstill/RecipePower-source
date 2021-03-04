require 'scraping/parser.rb'
module RecipeContentsHelper
  def recipe_content recipe_or_decorator
    decorator = recipe_or_decorator.is_a?(Draper::Decorator) ? recipe_or_decorator : recipe_or_decorator.decorate
    with_format('html') { render 'collectible/show_content', decorator: decorator, presenter: present(decorator) }
  end

  def recipe_content_replacement recipe_or_decorator
    [ 'div.content-item', recipe_content(recipe_or_decorator) ]
  end

  # Assert an annotation button in the recipe_contents editor. Give it a title, and declare its token for submission
  def annotation_button token, options={}
    button_options = options.merge(data: {'recipe[recipe_contents][token]' => token},
                                   class: "#{options[:class]} submit-selection",
                                   button_style: 'default')
    dialog_submit_button Parser.token_to_title(token, default: '+ Name'), button_options
  end

  # Button in the recipe_contents editor to accept a tag. Give it a title, and declare its token for submission
  def tag_usage_button tagtype, tagname, options={}
    button_options = options.merge(data: {'recipe[recipe_contents][tagname]' => tagname},
                                   class: "#{options[:class]} submit-selection",
                                   button_style: 'default')
    dialog_submit_button "Accept '#{tagname}' as a new #{Tag.typename(tagtype)}", button_options
  end
end
