class CreateMercuryResult < ActiveRecord::Migration[5.1]
  def change
	unless ActiveRecord::Base.connection.table_exists?("mercury_results")
    	  create_table :mercury_results do |t|
      	    t.text :results, default: "--- {}\n"
              t.integer :http_status
              t.text :error_message

              t.integer :status, default: 0
              t.integer :dj_id

              t.timestamps
          end
        end

        add_column :page_refs, :mercury_result_id, :integer
        remove_column :page_refs, :mercury_results, :text
  end
end
