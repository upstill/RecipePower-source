class CreateSiteReferents < ActiveRecord::Migration
  def change
    create_table :site_referents do |t|

      t.timestamps
    end
  end
end
