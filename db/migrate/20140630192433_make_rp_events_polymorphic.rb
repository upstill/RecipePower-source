class MakeRpEventsPolymorphic < ActiveRecord::Migration
  def change
    add_column :rp_events, :source_type, :string, :default => "User"
  end
end
