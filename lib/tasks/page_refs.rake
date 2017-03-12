namespace :page_refs do
  desc "TODO"

  # Nuke answers.com page_refs (because they're useless)
  task fix_answers: :environment do
    s = Site.first
    pr = PageRef.first
    dpr = DefinitionPageRef.find_by url: "http://www.answers.com"
    dpr.referments.delete_all
    dpr.aliases = []
    dpr.save
  end

  task fix_references: :environment do
    # run task sites:convert_references
    # run task recipes:convert_references
    # run task definitions:convert_references
    def self.fix_references what=nil
      # Make sure bad and good status align with existence of 'domain' attribute
      what = what.nil? ? :all : what.to_sym
      reports = []
      # Sites should be setup first so that other page_refs get them
      if [:all, :definitions].include? what
        reports += RefermentServices.convert_references
        reports += self.join_urls 'Definition'
        reports += DefinitionPageRef.all.collect { |pr| PageRefServices.new(pr).ensure_status }.flatten.compact.sort
        reports += DefinitionPageRef.where(site_id: nil).collect { |pr| PageRefServices.new(pr).ensure_site }.flatten.compact.sort
      end

      # QA
      bad_urls = PageRef.where.not('url LIKE ?', 'http%')
      reports << "#{bad_urls.count} PageRefs with funky URLS"
      reports += bad_urls.collect { |rpr| "\t#{rpr.url} (#{rpr.class} ##{rpr.id})" }.sort

      # Invoke recipes: reports (reports += self.recipe_reports) if [:all, :recipes].include? what
      # Invoke definitions: reports (reports += self.def_reports) if [:all, :definitions].include? what
      # Invoke sites: reports (reports += self.site_reports) if [:all, :sites].include? what
      puts reports.compact
    end

  end

end
