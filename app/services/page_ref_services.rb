class PageRefServices
  attr_accessor :page_ref
  # Eliminate redundancy in the PageRefs by folding two into one
  def absorb other
    # Take on all the recipes of the other
    other.recipes.each { |other_recipe|
      other_recipe.page_ref = page_ref
      other_recipe.save
    }

    # Take on all the urls of the other
    page_ref.aliases |= other.aliases + [other.url]
    page_ref.save
    other.destroy
  end
end