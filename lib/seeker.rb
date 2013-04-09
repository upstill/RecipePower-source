require "candihash.rb"

class Seeker < Object
  
  @@page_length = 20

  # Save the Seeker data into session store
  def store
    # Serialize structure consisting of tagstxt and specialtags
    savestr = YAML::dump( { :tagstxt => (@tagstxt || ""), :kind => @kind, :page => @cur_page || 1 } ) 
    back = YAML::load(savestr)
    savestr
  end
  
  def initialize affiliate, datastr=nil
    @affiliate = affiliate
    prior = !datastr.blank? && YAML::load(datastr)
    if prior && (prior[:kind] == @kind)
      @tagstxt = prior[:tagstxt] || ""
      @cur_page = prior[:page] || 1
    else
      @tagstxt = "" 
      @cur_page = 1
    end
  end
  
  def tagstxt()
    @tagstxt
  end
  
  def guide()
    # Describe this seeker for presentation to the user
    (@affiliate && @affiliate.selected) ? @affiliate.selected.guide : "This is your friendly seeker"
  end
  
  def hints()
    (@affiliate && @affiliate.selected) ? @affiliate.selected.hints : "Handy Hints Here"
  end
  
  # Accept new tags text, bust the cache, and return the new set of tags
  def tagstxt=(txt)
    # We either use the current tagstxt or the parameter, updating the tagstxt as needed
    @tagstxt = txt
    @tags = nil
    tags
  end
  
  def entity_name
    list_type.to_s
  end
  
  # Update the contents and return true OR enqueue the update job and return false
  def refresh
    # By default, we're ready to go, but the affiliate may have to fire off an update job in background
    @affiliate.respond_to?(:refresh) ? @affiliate.refresh : true
  end
  
  def updated_at
    @affiliate.respond_to?(:updated_at) && @affiliate.updated_at
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
  
  # Are there any recipes waiting to come out of the query?
  def empty?
    result_ids.empty?
  end
  
  def npages
    (result_ids.count+(@@page_length-1))/@@page_length
  end
  
  def cur_page
    @cur_page
  end
  
  def cur_page=(pagenum)
    @cur_page= pagenum
  end
  
  # Return a list of results based on the query tags and the paging parameters
  def results_paged
    npg = npages
    ids = result_ids 
    first = 0
    ixbound = ids.count 
    if npg > 1
      # Clamp current page to last page
      self.cur_page = npg if cur_page > npg
      # Now get index bounds for the records on the page
      first = (cur_page-1)*@@page_length
      last = first+@@page_length
      ixbound = last if ixbound > last
    end
    convert_ids ids[first...ixbound]
  end

  # If the entity has returned no results, suggest what the problem might have been
  def explain_empty
    report = "It looks like there aren't any #{entity_name.pluralize} that match your search"
    case tags.count
    when 0
      sug = nil
    when 1
      sug = "a different tag or no tag at all up there"
    else
      sug = "changing and/or deleting tags up there"
    end
    report+((sug && ".<br>You might try #{sug}.") || ".")
  end

end

class ContentSeeker < Seeker
  
  def initialize(affiliate, strdata)
    super
    @kind = 1
  end
  
  def query_path
    "/collection/query"
  end
  
  def cur_page
    @affiliate.cur_page
  end
  
  def cur_page=(pagenum)
    @affiliate.cur_page= pagenum
  end
  
  def convert_ids list
    @affiliate.convert_ids list
  end
  
  def timestamp obj
    @affiliate.timestamp obj
  end
  
  def list_type
    @affiliate.list_type
  end
  
  # Get the results of the current query.
  def result_ids
    @affiliate.result_ids tags
  end
  
  # If the entity has returned no results, suggest what the problem might have been
  def explain_empty
    explanation = @affiliate.explain_empty tags
    (explanation[:sug] ? explanation[:report]+"<br>You might try #{explanation[:sug]}." : explanation[:report])+"<br>"+explanation[:hint]
  end
end

class FriendSeeker < Seeker
  
  def initialize(affiliate, strdata)
    super
    # The affiliate is an ActiveRecord relation, the set of candidate users
    @kind = 2
  end

  def query_path
    "/users/query"
  end
  
  def convert_ids list
    User.where(id: list)
  end
  
  def list_type
    :user
  end
  
  def entity_name
    @affiliate.channel? ? "channel" : "user"
  end
  
  # Get the results of the current query.
  def result_ids
  	return @results if @results # Keeping a cache of results
    if tags.empty?
      @results = @affiliate.map(&:id)
    else
      # We purge/massage the list only if there is a tags query here
      # Otherwise, we simply sort the list by mod date
      # Convert candidate array to a hash recipe_id=>#hits
      candihash = Candihash.new @affiliate.map(&:id)
            
      # Rank/purge for tag matches
      tags.each { |tag| 
        # candihash.apply tag.recipe_ids if tag.id > 0 # A normal tag => get its recipe ids and apply them to the results
        # Get candidates by matching the tag's name against recipe titles and comments
        candihash.apply @affiliate.where("username LIKE ?", "%#{tag.name}%").map(&:id)
        candihash.apply @affiliate.where("email LIKE ?", "%#{tag.name}%").map(&:id)
        candihash.apply @affiliate.where("fullname LIKE ?", "%#{tag.name}%").map(&:id)
        candihash.apply @affiliate.where("about LIKE ?", "%#{tag.name}%").map(&:id)
      }
      # Convert back to a list of results
      @results = candihash.results.reverse
  	end
  end
end

class FeedSeeker < Seeker
  
  def initialize(affiliate, strdata)
    super
    @kind = 3
  end

  def query_path
    "/feeds/query"
  end
  
  def convert_ids list
    Feed.where(id: list)
  end
  
  def list_type
    :feed
  end
  
  # Get the results of the current query.
  def result_ids
  	return @results if @results # Keeping a cache of results
    if tags.empty?
      @results = @affiliate.map(&:id)
    else
      # We purge/massage the list only if there is a tags query here
      # Otherwise, we simply sort the list by mod date
      # Convert candidate array to a hash recipe_id=>#hits
      candihash = Candihash.new @affiliate.map(&:id)
            
      # Rank/purge for tag matches
      tags.each { |tag| 
        semantic_list = Feed.where(site_id: Site.where(referent_id: tag.referent_ids).map(&:id)).map(&:id)
        candihash.apply semantic_list
        # Get candidates by matching the tag's name against recipe titles and comments
        candihash.apply @affiliate.where("description ILIKE ?", "%#{tag.name}%").map(&:id)
        candihash.apply @affiliate.where("title ILIKE ?", "%#{tag.name}%").map(&:id)
      }
      # Convert back to a list of results
      @results = candihash.results.reverse
  	end
  end
end
