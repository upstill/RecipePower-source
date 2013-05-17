class LinkRefServices
  
  def initialize(lr)
    @lr = lr
  end
  
  # Make the link_refs unnecessary by transferring content to References
  def self.obviate(report_only=false)
    if report_only
      report = []
      rownum = 0
      tagarr = []
      Tag.all.each do |tag| 
        tagarr[tag.id] = tag 
        if (tag.tagtype == 0) && !tag.links.empty?
          report << "Tag ##{tag.id.to_s}(#{tag.name}): No tagtype, but has link(s): "+tag.links.each { |link| "##{link.id.to_s}(#{link.uri})" }.join('\n\t')
        end
      end
      unless report.empty?
        puts 'Tag report: \n'+report.join('\n\t') 
        return
      end
      rownum = 0
      Link.all.each do |link|
        if link.tags.size > 1
          refid = nil
          if link.tags.any? { |tag| !tag.referent_id } # || (refid ? (refid != tag.referent_id) : !(refid = tag.referent_id) ) }
            report << "Link #{link.id}(#{link.uri}) on tags \n\t"+link.link_refs.collect{ |lr| tag = tagarr[lr.tag_id]
              "LinkRef ##{lr.id.to_s}, Tag ##{tag.id.to_s} (#{tag.name}--#{tag.typename}), "+(tag.referent_id ? "ref. ##{tag.referent_id.to_s}" : "no ref")
            }.join("\n\t")
          end
        end
      end
      puts "Reference report:\n"+report.join("\n")
    else
      LinkRef.all[0..5].each { |lr| Delayed::Job.enqueue lr }
    end
    nil
  end
  
end