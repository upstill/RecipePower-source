
def add_tags type, names
  return unless names.present?
  typenum = Tag.typenum(type)
  names.each { |name|
    next if Tag.strmatch(name, tagtype: typenum).present?
    tag = Tag.assert name, typenum
  }
end

def prep_site site, selector, trimmers, grammar_mods={}
  if finder = site.finder_for('Content')
    finder.selector = selector
  else
    site.finders.build label: 'Content', selector: selector, attribute_name: 'html'
  end
  site.trimmers = trimmers
  site.grammar_mods = grammar_mods
  site.bkg_land # Now the site should be prepared to trim recipes
end

# Go out to the web, fetch the recipe at 'url', and ensure that all setup has occurred
# url: the URL to hit
# selector: a CSS selector for extracting content from the page
# trimmers: CSS selectors for content to be removed from the result
def load_recipe url_or_recipe, selector, trimmers, grammar_mods={}
  recipe = url_or_recipe.is_a?(Recipe) ? url_or_recipe : Recipe.new(url: url_or_recipe)
  prep_site recipe.site, selector, trimmers, grammar_mods
  recipe.bkg_launch
  recipe.bkg_land # Perform all due diligence
  assert_equal grammar_mods, recipe.site.grammar_mods
  refute recipe.errors.any?
  assert recipe.good? # Should have loaded and settled down

  assert recipe.recipe_page
  assert recipe.recipe_page.good?
  content = SiteServices.new(recipe.site).trim_recipe recipe.page_ref.content
  assert_equal content, recipe.recipe_page.content
  recipe
end

def load_page_ref url_or_page_ref, selector, trimmers, grammar_mods={}
  page_ref = case url_or_page_ref
             when String
               PageRef.new url: url_or_page_ref, kind: 'recipe'
             when PageRef
               url_or_page_ref
             when Recipe
               url_or_page_ref.page_ref
             end
  prep_site page_ref.site, selector, trimmers, grammar_mods
  page_ref.bkg_land # Perform all due diligence
  assert_equal grammar_mods, page_ref.site.grammar_mods
  refute page_ref.errors.any?
  assert page_ref.good? # Should have loaded and settled down
  assert (recipe_page = page_ref.recipe_page)
  recipe_page.bkg_land # Parse the RecipePage out into recipes
  assert recipe_page.good?
  content = SiteServices.new(page_ref.site).trim_recipe page_ref.content
  assert_equal content, page_ref.recipe_page.content
  page_ref
end
