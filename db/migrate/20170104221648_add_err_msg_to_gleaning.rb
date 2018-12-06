class AddErrMsgToGleaning < ActiveRecord::Migration[4.2]
  def change
    add_column :gleanings, :http_status, :integer
    add_column :page_refs, :http_status, :integer
    add_column :gleanings, :err_msg, :text
  end
end
