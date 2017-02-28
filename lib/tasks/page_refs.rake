namespace :page_refs do
  desc "TODO"
  task fix_answers: :environment do
    s = Site.first
    pr = PageRef.first
    dpr = DefinitionPageRef.find_by url: "http://www.answers.com"
    dpr.referments.delete_all
    dpr.aliases = []
    dpr.save
=begin
    index = { }
    dpr.aliases.each { |als|
      case als
        when /^http:\/\/www.answers.com\/topic\/(.*)$/
          (index[$1] ||= []) << als
        when /^http:\/\/www.answers.com\/search\?q=(.*)$/
          (index[$1] ||= []) << als
        else
          puts "Odd alias #{als}"
      end
    }
    orphans = dpr.referments.collect { |ref|
      name = ref.name.downcase.gsub ' ', '-'
      if matches = (index[name] || index[name+'-1'])
        puts "#{ref.name} => #{matches.join ', '}\n"
        if (matches.count == 1) && (match = dpr.aliases.delete(matches.first))
          puts "Deleted #{match}"
        end
      else
        ref.name
      end
    }.compact
    puts "#{orphans.count} orphans:"
    puts orphans
=end
  end

end
