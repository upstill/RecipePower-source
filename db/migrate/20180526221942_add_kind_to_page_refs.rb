class AddKindToPageRefs < ActiveRecord::Migration
  def up
    remove_index :page_refs, name: "page_refs_index_by_url_and_type"
    add_index :page_refs, :url, unique: true, using: 'btree', name: "page_refs_index_by_url"
    add_column :page_refs, :kind, :integer, default: 1
    rename_column :page_refs, :type, :otype
    # Ensure all page refs for sites point back to the site
    rcp_pointers = Recipe.all.group(:page_ref_id).count
    site_pointers = Site.all.group(:page_ref_id).count
    rfm_pointers = Referment.where(referee_type: "PageRef").group(:referee_id).count
    Site.includes(:page_ref).all.each { |site|
      if (page_ref = site.page_ref) && !page_ref.site
        page_ref.site = site
        page_ref.save
      end
    }
    PageRef.all.each { |pr|
      unless rcp_pointers[pr.id] || site_pointers[pr.id] || rfm_pointers[pr.id]
        pr.destroy
      else
        # Purge orphaned PageRefs
        otype = pr.read_attribute :otype
        pr.kind =
            case otype
              when 'PageRef'
                'link'
              when 'RecipePageRef'
                'recipe'
              when 'SitePageRef'
                'site'
              when 'ReferrablePageRef'
                'referrable'
              when 'DefinitionPageRef'
                'about'
              when 'ArticlePageRef'
                'article'
              when 'NewsitemPageRef'
                'news_item'
              when 'TipPageRef'
                'tip'
              when 'VideoPageRef'
                'video'
              when 'HomepagePageRef'
                'home_page'
              when 'ProductPageRef'
                'product'
              when 'OfferingPageRef'
                'offering'
              when 'EventPageRef'
                'event'
              else
                raise "Unknown type #{otype} for conversion to kind"
            end
        pr.save
      end
    }
  end

  def down
    rename_column :page_refs, :otype, :type
    remove_column :page_refs, :kind
    remove_index :page_refs, name: "page_refs_index_by_url"
    add_index :page_refs, [:url, :type], unique: true, using: 'btree', name: "page_refs_index_by_url_and_type"
  end
end
