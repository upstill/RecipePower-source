
def add_tags type, names
  return unless names.present?
  typenum = Tag.typenum(type)
  names.each { |name|
    next if Tag.strmatch(name, tagtype: typenum).present?
    tag = Tag.assert name, typenum
  }
end

def prep_site site, selector, trimmers, grammar_mods={}
  site.finders.build label: 'Content', selector: selector, attribute_name: 'html'
  site.trimmers = trimmers
  site.bkg_land # Now the site should be prepared to trim recipes
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
  prep_site page_ref.site, selector, trimmers, grammar_mods={}
  page_ref.bkg_land # Perform all due diligence
  page_ref
end

# Go out to the web, fetch the recipe at 'url', and ensure that all setup has occurred
# url: the URL to hit
# selector: a CSS selector for extracting content from the page
# trimmers: CSS selectors for content to be removed from the result
def load_recipe url, selector, trimmers, grammar_mods={}
  # TODO: install grammar_mods in the Site for the use of the recipe parse
  recipe = Recipe.new url: url
  prep_site recipe.site, selector, trimmers, grammar_mods={}
  recipe.bkg_land
  recipe
end
