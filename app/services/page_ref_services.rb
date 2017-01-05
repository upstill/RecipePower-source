# require 'page_ref.rb'
class PageRefServices
  attr_accessor :page_ref

  def initialize page_ref
    @page_ref = page_ref
    # @current_user = current_user
  end

  # Eliminate redundancy in the PageRefs by folding two into one
  def absorb other
    return if page_ref == other

    # Take on all the recipes of the other
    other.recipes.each { |other_recipe|
      other_recipe.page_ref = page_ref
      other_recipe.save
    } if other.respond_to? :recipes

    other.sites.each { |other_site|
      other_site.page_ref = page_ref
      other_site.save
    } if other.respond_to? :sites

    (page_ref.attributes.keys -
        %w{ id type url errcode status dj_id created_at updated_at aliases error_message }).each { |attrname|
      page_ref.write_attribute(attrname, other.attributes[attrname]) unless page_ref.attributes[attrname].present?
    }
    page_ref.status = other.status

    # Take on all the urls of the other
    page_ref.aliases |= other.aliases + [other.url] - [page_ref.url]
    page_ref.save
    other.destroy
  end

  # Convert a reference, either creating a new PageRef or merging it with another
  def self.convert_reference reference, extant_pr=nil

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
    RecipeServices.convert_references
    # RefermentServices.convert_references
    SiteServices.convert_references

    # First, clean up the PageRefs with nil URLs
    SitePageRef.where(url: nil).collect { |spr|
      site = Site.find_by(page_ref_id: spr.id)
      spr.destroy
      if site
        site.page_ref = nil
        site.save
        SiteServices.new(site).convert_references
      end
    }

    # First, clean up the PageRefs with nil URLs
    puts RecipePageRef.where(url: nil).collect { |pr|
           pr.recipes.collect { |recipe|
             RecipeServices.new(recipe).correct_url_or_destroy
           }
         }.flatten.compact.sort

    puts RecipePageRef.bad.includes(:recipes).collect { |pr|
           pr.recipes.collect { |recipe|
             RecipeServices.new(recipe).correct_url_or_destroy
           }
         }.flatten.compact.sort

    # QA
    puts RecipePageRef.where(url: nil).count.to_s + ' nil recipe urls'
    puts RecipePageRef.bad.count.to_s + ' bad recipe refs'
    puts DefinitionPageRef.where(url: nil).count.to_s + ' nil definition urls'
    puts DefinitionPageRef.bad.count.to_s + ' bad definition refs'
    puts SitePageRef.where(url: nil).count.to_s + ' nil site urls'
    puts SitePageRef.bad.count.to_s + ' bad site refs'

    nil
  end

  # Try to make a URL good by applying a pattern (string or regexp)
  def try_substitute old_ptn, subst
    old_url = page_ref.url
    if old_url.match(old_ptn)
      new_url = old_url.sub old_ptn, subst
      puts "Trying substituting #{new_url} for #{old_url}"
      new_page_ref = page_ref.class.fetch new_url, false # Don't persist
      if new_page_ref.good?
        if new_page_ref.id
          # Make the old page_ref represent the new URL
          new_page_ref.aliases += [new_url] unless new_page_ref.url == new_url
          PageRefServices.new(new_page_ref).absorb page_ref
          new_page_ref
        else # Not saved => we can just keep the old pageref and adopt the outcome
          # Adopt the new_url
          page_ref.aliases += [page_ref.url]
          page_ref.url = new_page_ref.url
          absorb new_page_ref
          page_ref
        end
      end
    end
  end

end