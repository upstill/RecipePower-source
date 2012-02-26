class CreateSites < ActiveRecord::Migration
  def change
    create_table :sites do |t|
      t.string :site # Root of all site material; may include a path in addition to the domain
      t.string :sample # One page from the site, for testing purposes; may be relative to :site path
      t.string :home # The home page--which, again, may differ from the site, e.g. splendidtable.publicradio.org
      t.string :subsite # diff. parts of a site may have different parsings; this field
      			# identifies them by path

      # The following three fields come out of parsing a URL
      t.string :scheme # The scheme portion of a recipe URL
      t.string :host # The host portion of a recipe URL
      t.string :port # ...because you never know...

      t.string :name # Title of the site, for display purposes
      t.string :logo # URL of logo, if permitted and desirable

      # The tags field for a site is held in a virtual attribute 'tags'
      # It is derived from and YAML'ed to this field:
      t.text :tags_serialized

      t.timestamps
    end
  end
end
