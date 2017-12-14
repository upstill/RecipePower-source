namespace :recipes do
  desc "TODO"

  # QA on recipes: try to get valid PageRef
  task probe: :environment do
    # Take another look at the recipes' links which haven't been validated
      reports = []
      unreachables = Recipe.includes(:page_ref, :gleaning).all.collect { |recipe| recipe if recipe.reachable? == false }.compact
      reports << "**** Rechecking #{unreachables.count} recipes..."
      reports += unreachables.collect { |unreachable|
        # Take another crack at the unreachable recipes
        PageRefServices.new(unreachable.page_ref).ensure_status true
      }.compact
      unreachables = Recipe.includes(:page_ref, :gleaning).all.collect { |recipe| recipe if recipe.reachable? == false }.compact
      reports << "**** #{unreachables.count} recipes unreachable after checking"
  end

  # OBSOLETE when there are no more RecipeReferences
  task convert_references: :environment do
    # Ensure all recipes have a PageRef
    reports = ['***** rake recipes:convert_references ********']
    Recipe.includes(:page_ref).where(id: RecipeReference.all.pluck(:affiliate_id)).collect { |rec|
      if !rec.page_ref || rec.page_ref.url.blank?
        if rec.page_ref
          rec.page_ref.destroy
          rec.reload
        end
        # RecipeServices.new(rec).convert_references
        puts "Converting references for recipe #{rec.id}:"
        RecipeReference.where(affiliate_id: rec.id).each { |reference|
          reference.bkg_launch # rec.page_ref = PageRefServices.convert_reference reference, rec.page_ref
          puts "Enqueued RecipePageReference ##{reference.id} (#{reference.url})"
          reference.bkg_land
          puts "...returned"
        }
        rec.reload
      end
    }

    procids =
        (PageRef::RecipePageRef.virgin.pluck(:id) +
            RecipePageRef.processing.pluck(:id) +
            RecipePageRef.bad.pluck(:id) +
            RecipePageRef.where(http_status: nil).pluck(:id)
        ).uniq.sort

    # Ensure all RecipePageRefs have valid status and http_status
    RecipePageRef.where(id: procids).each { |pr| PageRefServices.new(pr).ensure_status }

    # Clean up the PageRefs with nil URLs
    reports += RecipePageRef.includes(:recipes).where(url: nil).collect { |pr|
      pr.recipes.collect { |recipe|
        RecipeServices.new(recipe).correct_url_or_destroy
      }
    }.flatten.compact.sort

    reports += RecipePageRef.bad.includes(:recipes).collect { |pr|
      if pr.recipes.present?
        pr.recipes.collect { |recipe|
          RecipeServices.new(recipe).correct_url_or_destroy
        }
      else
        "RecipePageRef #{pr.id} (#{pr.url}) has no recipes"
      end
    }.flatten.compact.sort
    reports += PageRefServices.join_urls Recipe
    # Finally, ensure that all RecipePageRef objects have either :good or :bad status and also valid http_status
    reports += RecipePageRef.all.collect { |pr| PageRefServices.new(pr).ensure_status }.flatten.compact.sort
    RecipePageRef.where(site_id: nil).collect { |pr| PageRefServices.new(pr).ensure_site }.flatten.compact.sort
    puts reports
  end

  task :reports => :environment do
    # Every recipe needs to have a site and a url (page_ref)
    # reports << Recipe.includes(:referent).to_a.collect { |recipe| "Recipe ##{recipe.id} has no referent (ERROR)" unless recipe.referent }.compact

    puts RecipePageRef.where(url: nil).count.to_s + ' nil urls in RecipePageRefs'
    puts RecipePageRef.where(site_id: nil).count.to_s + ' nil sites in RecipePageRefs'
    puts Recipe.includes(:page_ref).collect { |rcp| true if rcp.page_ref.url.blank? }.compact.count.to_s + " nil URLs in recipes"

    bad = RecipePageRef.includes(:recipes).where.not(status: [0,1,2], http_status: 200)
    unreachables = Recipe.includes(:page_ref, :gleaning).all.collect { |recipe| recipe if recipe.reachable? == false }.compact
    headless = Recipe.includes(:page_ref).where(page_ref_id: nil)
    # Every PageRef should have at least tried to go out
    puts [
        ((RecipePageRef.virgin.includes(:recipes).count+RecipePageRef.processing.count).to_s + ' Recipe Page Refs need processing'),
        (RecipePageRef.includes(:recipes).where(http_status: nil).count.to_s + ' Recipe Page Refs have no HTTP status'),
        (bad.count.to_s + " bad recipe refs\n\t" + bad.collect { |rpr| "'#{rpr.url}' (#{rpr.id}) (http_status = #{rpr.http_status}) used by recipe(s) #{rpr.recipe_ids} "}.sort.join("\n\t")),
        (unreachables.count.to_s + " recipe(s) with unreachable URL (bad PageRef and bad gleaning)\n\t" + unreachables.collect { |badrecipe| "#{badrecipe.page_ref.url if badrecipe.page_ref} (#{badrecipe.id}) "}.sort.join("\n\t"))
    ].flatten.compact
    puts (["#{headless.count} recipes with no page ref:"] +
        headless.collect { |recipe| "Recipe ##{recipe.id} '#{recipe.url}'" }).join("\n\t")
  end
end
