namespace :gleanings do
  desc "TODO"

  # QA on recipes: try to get valid PageRef
  task fix_links: :environment do
    Gleaning.all.each { |gl|
      next unless gl.page_ref && gl.page_ref.url.present? && gl.results && gl.results['Image']
      puts "============================================"
      puts "Gleaning ##{gl.id} for '#{gl.page_ref.url}'"
      gl.results['Image'].each { |result|
        urls = result.out.collect { |url|
          puts url
          corrected = safe_uri_join(gl.page_ref.url, url).to_s rescue nil
          if url == corrected
            url
          else
            puts " => #{corrected || 'Bad URL'}"
            corrected
          end
        }.compact
        result.out = urls
      }
      if gl.changed?
        puts "Saving Gleaning ##{gl.id}"
        gl.save
        break;
      end
    }
  end
end
