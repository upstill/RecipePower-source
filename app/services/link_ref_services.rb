class LinkRefServices
  
  def initialize(lr)
    @lr = lr
  end
  
  # Make the link_refs unnecessary by transferring content to References
  def self.obviate(report_only=true)
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
    if report_only
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
    else
      LinkRef.all.each do |lr|
        tag = tagarr[lr.tag_id]
        link = lr.link
        if ref = Reference.seek_on_url(link.uri)
          report << "Row ##{rownum.to_s}: Link #{link.id.to_s}(#{link.uri}) already associated with tag."
        elsif !Reference.assert(link.uri, tag)
          report << "Row ##{rownum.to_s}: Couldn't reference tag ##{tag.id.to_s}(#{tag.name}) because "+(lr.referents.empty? ? "it has no referents" : "Who knows why? (It has referents)")
        end
        rownum = rownum+1
      end
    end
    puts "Reference report:\n"+report.join("\n")
    nil
  end
  
end