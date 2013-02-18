class Seeker < Object
  
  # Save the Seeker data into session store
  def store
    # Serialize structure consisting of tagstxt and specialtags
    YAML::dump( { :tagstxt => (@tagstxt || ""), :kind => @kind } ) 
  end
  
  def initialize affiliate, datastr=nil
    case @affiliate = affiliate
    when ContentBrowser
      @kind = 1
    when FeedBrowser
      @kind = 2
    end
    prior = !datastr.blank? && YAML::load(datastr)
    @tagstxt = (prior && (prior.kind == kind)) ? prior[:tagstxt] : "" 
  end
  
  def tagstxt()
    @tagstxt
  end
  
  # Accept new tags text, bust the cache, and return the new set of tags
  def tagstxt=(txt)
    # We either use the current tagstxt or the parameter, updating the tagstxt as needed
    @tagstxt = txt
    @tags = nil
    tags
  end
  
  # Use the 'querytags' string (in actuality a string provided by the unconstrained tags editor) to extract
  # a set of tag tokens. The elements of the comma-separated string are either 1) a positive integer, representing
  # a tag in the dictionary, or 2) an arbitrary other string on which to query.
  # The tags method converts the latter into a transitory tag with a negative value, an index into an internally-stored
  # array of pseudo-tags
  def tags
    return @tags if @tags # Use cache, if any
    newspecial = {}
    oldspecial = @specialtags || {}
    # Accumulate resulting tags here:
    @tags = []
    @tagstxt.split(",").each do |e| 
      e.strip!
      if(e=~/^\d*$/) # numbers (sans quotes) represent existing tags that the user selected
        @tags << Tag.find(e.to_i)
      elsif e=~/^-\d*$/  # negative numbers (sans quotes) represent special tags from before
        # Re-save this one
        tag = Tag.new(name: (newspecial[e] = oldspecial[e]))
        tag.id = e.to_i
        @tags << tag
      else
        # This is a new special tag. Convert to an internal tag and add it to the cache
        name = e.gsub(/\'/, '').strip
        unless tag = Tag.strmatch( name, { matchall: true, uid: @userid }).first
            tag = Tag.new( name: name )
            tag.id = -1
            # Search for an unused id
            while(newspecial[tag.id.to_s] || oldspecial[tag.id.to_s]) do
                tag.id = tag.id - 1
            end
            newspecial[tag.id.to_s] = tag.name
        end
        @tags << tag
      end
    end
    # Have to revise tagstxt to reflect special tags because otherwise, IDs will get 
    # revised on the next read from DB
    @tagstxt = @tags.collect { |t| t.id.to_s }.join ','
    @specialtags = newspecial
    @tags
  end
  
  # Get the results of the current query.
  def result_ids
    @affiliate.result_ids tags
  end
  
  def timestamp obj
    @affiliate.timestamp obj
  end
  
  # How many pages in the current result set?
  def npages
    @affiliate.npages tags
  end
  
  # Are there any recipes waiting to come out of the query?
  def empty?
    @affiliate.result_ids(tags).empty?
  end
  
  # Return a list of results based on the paging parameters
  def results_paged
    @affiliate.results_paged tags
  end
  
  # If the entity has returned no results, suggest what the problem might have been
  def explain_empty
    explanation = @affiliate.explain_empty tags
=begin
    report = "It looks like #{selected.handle} doesn't have anything that matches your search."
    case tags.count
    when 0
      sug = nil
    when 1
      sug = "a different tag or no tags at all up there"
    else
      sug = "removing a tag up there"
    end
    if selected.class.to_s =~ /Composite/ 
      if selected.children.empty?
        report = "There's no content here because you have no #{selected.content_name} selected."
        sug = " getting one by clicking the '+' sign over there to the left"
      elsif tags.empty?
        name = selected.content_name
        report = ((selected.children.count < 2) ? "This "+name.singularize+" doesn't" : "These "+name+" don't")+" appear to have any content."
        sug = nil
      else
        report = "It looks like there isn't anything that matches your search in '#{selected.handle}'."
      end
    else # Element
      if tags.empty?
        content = selected.content_name == "Feeds" ? "Entries" : "Recipes"
        report = "#{selected.handle} doesn't appear to have any #{content.downcase} at present."
        sug = nil
      end
    end
=end
    explanation[:sug] ? explanation[:report]+"<br>You might try #{explanation[:sug]}." : explanation[:report]
  end
  
  def cur_page
    @affiliate.cur_page
  end
  
  def cur_page=(pagenum)
    @affiliate.cur_page= pagenum
  end
  
  def list_type
    @affiliate.list_type
  end

end

class ContentSeeker < Seeker
  def query_path
    "/collection/query"
  end
end

class FeedSeeker < Seeker
  def query_path
    "/feeds/query"
  end
end