class PageRefServices
  attr_accessor :page_ref

  def initialize page_ref
    @page_ref = page_ref
    # @current_user = current_user
  end

  # Eliminate redundancy in the PageRefs by folding two into one
  def absorb other
    # Take on all the recipes of the other
    other.recipes.each { |other_recipe|
      other_recipe.page_ref = page_ref
      other_recipe.save
    } if other.respond_to? :recipes

    other.sites.each { |other_site|
      other_site.page_ref = page_ref
      other_site.save
    } if other.respond_to? :sites

    # Take on all the urls of the other
    page_ref.aliases |= other.aliases + [other.url] - [page_ref.url]
    page_ref.save
    other.destroy
  end

  # Convert a reference, either creating a new PageRef or merging it with another
  def self.convert_reference reference, extant_pr

    # Is the only difference between the two URLs a trailing slash in the link?
    def self.functionally_equivalent pr1, pr2
      uri1 = URI.parse pr1.url
      uri2 = URI.parse pr2.url
      return true if uri1 && uri1 && (uri2.path.sub /\/$/, '') == (uri1.path.sub /\/$/, '')
      # Mercury does not give the redirected URL for a "temporary" redirect, so we compare content
      c1 = pr1.content || ''
      return true if (c1.length > 1) && (c1 == (pr2.content || ''))
    end

    klass = reference.class.to_s.sub(/Reference$/, 'PageRef').constantize
    pr = klass.fetch reference.url
    return pr if pr.errors.any?
    case extant_pr
      when nil # No PageRef existed prior
        pr.save if !pr.id
        pr
      when pr
        extant_pr
      else # There's an existing page_ref and it doesn't match the new one
        # if functionally_equivalent(extant_pr, pr) # If it's only a difference of the trailing slash...
          # ...just merge the new pr into the old
          PageRefServices.new(extant_pr).absorb pr
          extant_pr
        # else
          # raise %Q{Reference #{reference.id} (#{reference.url}) fails to merge its PageRef (url=#{pr.url}) with existing PageRef #{extant_pr.id} (#{[[extant_pr.url]+extant_pr.aliases].join(', ')})}
        # end
    end
  end

  # Run this after convert_references has run to completion
  def self.fix_references
    msgs =
    RecipeReference.where('url LIKE ?', "http://www.bbc.co.uk/food/recipes/%").collect { |rr|
      rec = rr.affiliate
      if rec.page_ref.url.blank?
        rec.glean! true
        if rec.gleaning.bad?
          "Would be destroying recipe ##{rec.id} '#{rec.title}'" # rec.destroy
        end
      end
    }.compact

    RecipeReference.where('url LIKE ?', "%www.tasteofbeirut.com%").each { |rr|
      if rr.url.match(/\/\d\d\d\d\/\d\d/)
        rec = rr.affiliate
        pr = rec.page_ref
        if !pr || pr.url.blank?
          rr.url.sub! /\/\d\d\d\d\/\d\d/, ''
          rr.save

          # Redo the page_ref
          if pr
            pr.destroy
            rec.page_ref = nil
            rec.save
          end
          RecipeServices.new(rec).convert_references
        end
      end
    }
    puts msgs
    nil
  end

end