class CreateIndexOnPageRefs < ActiveRecord::Migration
  def change
    add_index  :page_refs, :aliases, using: 'gin'
  end
end
