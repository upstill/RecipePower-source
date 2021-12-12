# From Avdi Grim, in https://avdi.codes/throw-catch-raise-rescue-im-so-confused/

require 'rubygems'
require 'mechanize'

MAX_PAGES = 6

def each_google_result_page(query, max_pages=MAX_PAGES)
  i = 0
  a = Mechanize.new do |a|
    a.get('http://google.com/') do |page|
      search_result = page.form_with(:name => 'f') do |search|
        search.q = query
      end.submit

      yield search_result, i
      while i < max_pages
        search_result = search_result.link_with(:text => "Next").click
        i += 1
        yield search_result, i
      end
    end
  end
end

def show_rank_for(target, query)
  rank = catch(:rank) {
    each_google_result_page(query, 6) do |page, page_index|
      each_google_result(page) do |result, result_index|
        if result.text.include?(target)
          throw :rank, (page_index * 10) + result_index
        end
      end
    end
    "<not found>"
  }
  puts "#{target} is ranked #{rank} for search '#{query}'"
end

def each_google_result(page)
  page.root.css(".g").each_with_index do |result, i|
    yield result, i
  end
end