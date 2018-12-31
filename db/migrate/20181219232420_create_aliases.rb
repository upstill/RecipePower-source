class CreateAliases < ActiveRecord::Migration[5.0]
  def up
    drop_table :aliases if ActiveRecord::Base.connection.table_exists?("aliases")
    create_table :aliases do |t|
      t.integer :page_ref_id
      t.text :url, null: false

      t.timestamps
    end
    add_index(:aliases,
              :url,
              unique: true,
              using: 'btree',
              name: "aliases_index_by_url") unless index_name_exists?(:aliases, "aliases_index_by_url", false)
    # Copy aliases into new table
    data = PageRef.all.pluck(:id, :kind, :url, :aliases)
    saved_data = data.clone
    data.keep_if do |datum|
      # First, create an alias for each url of each PageRef. These are presumably canonical,
      # so it is most important to preserve those.
      id, kind, url, aliases = datum
      if al = Alias.find_by(Alias.url_query url)
        # If there's a collision on url
        logger.debug "Collision on #{url} with #{al.url}..."
        PageRefServices.new(al.page_ref).absorb PageRef.find(id)
        false
      else
        logger.debug "Creating Alias on url #{url}"
        al = Alias.create(page_ref_id: id, url: url)
        logger.debug "...saved as #{al.url}"
        true
      end
    end
    data.compact.each do |datum|
      # Now go through the aliases and attempt to define an Alias to its requisite PageRef
      # If any aliases from the PageRef collide with existing Aliases, let them go
      id, kind, url, aliases = datum
      aliases.each do |url|
        unless al = Alias.find_by(Alias.url_query url)
          reduced_url = Alias.reduced_url url
          logger.debug "Creating Alias on alias #{url} (reduced_url = '#{reduced_url}')..."
          al = Alias.create page_ref_id: id, url: url
          logger.debug "...saved as #{al.url}"
        end
      end
    end
    # Now test the original PageRef data for consistency
    violations = []
    saved_data.each do |datum|
      # Confirm that each url or alias has a correct home
      id, kind, orig_url, aliases = datum
      (aliases + [orig_url]).each do |url|
        al = Alias.find_by(Alias.url_query url)
        if !al
          violations << "URL '#{url}' (reduced to '#{Alias.reduced_to url}') can't be found!"
        elsif al.page_ref_id != id
          violations << "Url #{url}, originally from PageRef##{id} (#{kind}) now maps to PageRef##{al.page_ref_id} (url '#{al.page_ref.url}', kind '#{al.page_ref.kind}')"
        end
      end
    end
    puts violations
    remove_column :page_refs, :aliases
  end

  def down
    add_column :page_refs, :aliases, :text, array: true, default: []
    PageRef.all.each do |pr|
      aliases = Alias.where(page_ref: pr).pluck :url
      pr.update_attribute :aliases, (aliases - [pr.url])
    end
    drop_table :aliases
  end
end
