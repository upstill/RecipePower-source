namespace :definitions do
  desc "TODO"

  task reports: :environment do
    # Every PageRef needs to have a parsable URL
    puts PageRef.where(type: 'DefinitionPageRef', url: nil).count.to_s + ' nil urls in DefinitionPageRefs'
    puts Referent.where(type: 'DefinitionReferent').includes(:page_ref).to_a.collect { |defref| "Definition ##{defref.id} has no page_ref (ERROR)" unless defref.page_ref }.compact.sort

    puts DefinitionPageRef.where(site_id: nil).count.to_s + ' nil sites in DefinitionPageRefs'
    # Every PageRef should have at least tried to go out
    bad_def_refs = PageRef.bad.where("type = 'DefinitionPageRef' and http_status != 200")
    puts [
        ((PageRef.virgin.where(type: 'DefinitionPageRef').count+DefinitionPageRef.processing.count).to_s + ' Definition Page Refs need processing'),
        (PageRef.where(type: 'DefinitionPageRef', http_status: nil).count.to_s + ' Definition Page Refs have no HTTP status'),
        (bad_def_refs.count.to_s + " bad definition refs: \n\t" + bad_def_refs.collect { |dpr| "#{dpr.url} (#{dpr.id}) http_status = '#{dpr.http_status}'"}.sort.join("\n\t"))
    ]
  end
end
