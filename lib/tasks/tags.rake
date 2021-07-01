namespace :tags do
  desc "TODO"
  task :check_meanings => :environment do
    # Check for tags whose referent no longer exists
    orphans = Tag.includes(:primary_meaning).all.inject([]) { |memo, tag| (tag.referent_id && !tag.primary_meaning) ? (memo + [tag]) : memo }
  end

  task :renormalize => :environment do
    # Make the normalized name of each tag reflect the actual name
    Tag.all.each do |t|
      if t.normalized_name != Tag.normalize_name(t.name)
        puts "#{t.id}: #{t.name} => '#{t.normalized_name}', not '#{Tag.normalize_name t.name}'"
        t.update_attribute :normalized_name, Tag.normalize_name(t.name)
      end
    end
  end
end

