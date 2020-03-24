module RecipePagesHelper
  def show_recipe_page recipe_page
    with_format('html') { render 'recipe_pages/show_content', recipe_page: recipe_page }
  end

  def recipe_page_replacement rp
    [ 'div.results-enclosure', show_recipe_page(rp) ]
  end

  def do_recipe_pages_panel title, pane=:recipe_pages # do_panel
    render('recipe_pages/panel', title: title, pane_for: pane, wide: true)
  end
end
