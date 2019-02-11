class AddIndexToRcprefs < ActiveRecord::Migration[5.0]
  def up
    refs = {}
    Rcpref.all.each do |ref|
      key = "#{ref.user_id} #{ref.entity_type} #{ref.entity_id}"
      puts "Encountering #{key}"
      if oref = refs[key] # Error! Duplicated entry
        puts "ERROR: duplicated ref##{oref.id} in ref#{ref.id}:"
        oref.attributes.keys.each { |attrib| puts "\t#{attrib}:#{oref[attrib]}"}
        puts "\t------------------------"
        ref.attributes.keys.each { |attrib| puts "\t#{attrib}:#{ref[attrib]}"}
        ref.destroy
      else
        refs[key] = ref
      end
    end
    puts "Adding index to rcprefs"
    add_index :rcprefs, ["user_id","entity_type","entity_id"], :unique => true
  end
  def down
    if index_name_exists?(:rcprefs, "index_rcprefs_on_user_id_and_entity_type_and_entity_id", false)
      remove_index :rcprefs, name: "index_rcprefs_on_user_id_and_entity_type_and_entity_id"
    end
  end
end
