class AddVieweridToResultsCache < ActiveRecord::Migration[5.0]
  def up
    ResultsCache.delete_all
    remove_index(:results_caches, name: "index_results_caches_on_session_id_and_type_and_result_typestr") if index_name_exists?(:results_caches, "index_results_caches_on_session_id_and_type_and_result_typestr", false)
    add_column :results_caches, :viewer_id, :integer, null: false
    rename_column :results_caches, :result_typestr, :result_type
    add_index :results_caches, ["session_id","type","result_type","viewer_id"], :unique => true, name: 'results_cache_index'
  end
  def down
    remove_column :results_caches, :viewer_id
    rename_column :results_caches, :result_type, :result_typestr
    add_index :results_caches, ["session_id","type","result_typestr"], :unique => true
    remove_index(:results_caches, name: "results_cache_index") if index_name_exists?(:results_caches, "results_cache_index", false)
  end
end
