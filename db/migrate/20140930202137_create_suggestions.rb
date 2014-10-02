class CreateSuggestions < ActiveRecord::Migration
  def change
    create_table :suggestions do |t|
      t.string :base_type
      t.integer :base_id
      t.integer :viewer_id
      t.string :session
      t.text :filter
      t.integer :results_cache_id # Results of current query
      t.text :results # Totality of results, ready for display (may include a stream marker)
      t.string :type # This is a polymorphic class; types include UserSuggestion, SiteSuggestion, TagSuggestion, CollectionSuggestion
      t.integer :time_next, default: 1

      t.timestamps
    end
  end
end
