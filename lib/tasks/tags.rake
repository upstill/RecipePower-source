namespace :sites do
  desc "TODO"
  task :check_meanings => :environment do
    # Check for tags whose referent no longer exists
    orphans = Tag.includes(:primary_meaning).all.inject([]) { |memo, tag| (tag.referent_id && !tag.primary_meaning) ? (memo + [tag]) : memo }
  end
end

