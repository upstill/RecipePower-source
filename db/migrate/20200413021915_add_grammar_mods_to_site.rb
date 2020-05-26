class AddGrammarModsToSite < ActiveRecord::Migration[5.2]
  def change
    add_column :sites, :grammar_mods, :text
  end
end
