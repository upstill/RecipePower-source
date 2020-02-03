module RecipeContentsHelper
  def recipe_content recipe_or_decorator
    decorator = recipe_or_decorator.is_a?(Draper::Decorator) ? recipe_or_decorator : recipe_or_decorator.decorate
    with_format('html') { render 'collectible/show_contents', decorator: decorator, presenter: present(decorator) }
  end

  def recipe_content_replacement recipe_or_decorator
    [ 'div.card-content', recipe_content(recipe_or_decorator) ]
  end

  # Assert an annotation button in the recipe_contents editor. Give it a title, and declare its token for submission
  def annotation_button title, token, options={}
    dialog_submit_button title, options.merge(data: {token: token}, button_style: 'default') #  label, path_or_options, kind='default', size=nil, options={}
  end
end
