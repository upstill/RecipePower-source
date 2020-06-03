class ChangeColumnNullOnRcpref < ActiveRecord::Migration[5.2]
  def change
    change_column_null :rcprefs, :entity_id, false
  end
end
