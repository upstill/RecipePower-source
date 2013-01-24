class RenameNameInSite < ActiveRecord::Migration
  def up
    names = {}
    Site.all.each do |site| 
      if names[site.name]
        names[site.name] << site
      else
        names[site.name] = [ site ]
      end
    end
    winnow = []
    names.keys.each do |key| 
      if names[key].count > 1
        puts key+": "+names[key].map { |site| site.id.to_s+"/"+site.referent_id.to_s }.join(', ')
        save = nil
	# Go through all the sites associated with the name and confirm that their referent_ids
	# are all either nil or identical (i.e., no two different non-nil refererent_ids
	# That means it's safe to delete all but one site.
        winnow << (save || names[key].first) if names[key].all? do |site| 
          site.referent_id.nil? || (save ? (save.referent_id == site.referent_id) : (save=site) ) 
        end
      end
    end
    # For each site to be saved, destroy all others with the same name
    winnow.each { |saved|
      Site.where(name: saved.name).each { |site| 
        site.destroy unless (site == saved)
      }
    }
    # Now ensure that all sites have a referent and a Source tag
    Site.all.each do |site|
      unless site.referent
        site.referent = Referent.express(self.name, :Source)
        site.save
      end
    end
    Referent.where(type: "InterestReferent").each { |ir| ir.destroy }
    rename_column :sites, :name, :oldname
  end

  def down
    rename_column :sites, :oldname, :name
  end
end
