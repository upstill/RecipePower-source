require "candihash.rb"

class Seeker < Object
  
  @@page_length = 10

  # Save the Seeker data into session store
  def store
    # Serialize structure consisting of tagstxt and specialtags
    savestr = YAML::dump( datastore ) 
    back = YAML::load(savestr)
    savestr
  end
  
private 
  
  # class-specific data storage
  def datastore
    { 
      :tagstxt => (@tagstxt || ""), 
      :tagtype => @tagtype, 
      :page => @cur_page || 1,
      :items_per_page => @items_per_page
    }
  end
  
  def dataload datastr
    prior = !datastr.blank? && YAML::load(datastr)
    if prior
      @tagstxt = prior[:tagstxt] || ""
      @tagtype = prior[:tagtype]
      @cur_page = prior[:page] || 1
      @items_per_page = prior[:items_per_page] ? prior[:items_per_page].to_i : @@page_length
    else
      @tagstxt = "" 
      @tagtype = nil
      @cur_page = 1
      @items_per_page = @@page_length
    end
    prior || {}
  end
  
  def affiliate browser = nil, params = nil
    @affiliate ||= model_class.all
  end
public

  def initialize user, browser = nil, datastr = nil, params = nil
    @user = user
    # Retrieve prior data from datastr if provided
    dataload datastr
    # The affiliate is generally a scope, but in the case of the content browser, it's the browser itself
    affiliate browser, params # We leave it to subclasses to define a different affiliate from params
    # Params for tagstxt and cur_page will override the prior info
    if params
      @items_per_page = params[:items_per_page].to_i if params[:items_per_page]
      if params[:tagstxt]
        @tagstxt = params[:tagstxt]
        @tags = nil
        params[:cur_page] = 1
      end
      if ttstr = params[:tagtype]
        @tagtype = ttstr.empty? ? nil : ttstr.to_i
      end
      if page = params[:cur_page]
        self.cur_page = page.to_i
      elsif params[:next_page]
        params[:cur_page] = self.cur_page + 1
      end
    end
    if params && params[:cur_page]
      self.cur_page = params[:cur_page].to_i
    end
  end

  def query_path
    "/#{entity_name.pluralize}"
  end
  
  def model_class
    entity_name.capitalize.constantize
  end
  
  def convert_ids list
    model_class.where(id: list)
  end
  
  def list_type
    entity_name.to_sym
  end
  
  def entity_name
    self.class.to_s.sub(/Seeker$/, '').downcase
  end
  
  def table_header
    entity_name.capitalize.pluralize
  end
  
  def tagstxt()
    @tagstxt
  end
  
  def tagtype
    @tagtype
  end
  
  def guide
    # Describe this seeker for presentation to the user
    (affiliate && @affiliate.respond_to?(:selected) && @affiliate.selected) ? @affiliate.selected.guide : "This is your friendly seeker"
  end
  
  def hints
    (affiliate && @affiliate.respond_to?(:selected) && @affiliate.selected) ? @affiliate.selected.hints : "Handy Hints Here"
  end
  
  # Accept new tags text, bust the cache, and return the new set of tags
  def tagstxt=(txt)
    # We either use the current tagstxt or the parameter, updating the tagstxt as needed
    @tagstxt = txt
    @tags = nil
    tags
  end
  
  # Update the contents and return true OR enqueue the update job and return false
  def refresh
    # By default, we're ready to go, but the affiliate may have to fire off an update job in background
    affiliate.respond_to?(:refresh) ? affiliate.refresh : true
  end
  
  def updated_at
    affiliate.respond_to?(:updated_at) && affiliate.updated_at
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
    (result_ids.count+(@items_per_page-1))/@items_per_page
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
      first = (cur_page-1)*@items_per_page
      last = first+@items_per_page
      ixbound = last if ixbound > last
    end
    convert_ids ids[first...ixbound]
  end
  
  # Return the list of ids matching the tags, by calling an application method
  def result_ids
  	return @results if @results # Keeping a cache of results
    if tags.empty?
      @results = affiliate.map(&:id)
    else
      # We purge/massage the list only if there is a tags query here
      # Otherwise, we simply sort the list by mod date
      # Convert candidate array to a hash recipe_id=>#hits
      candihash = Candihash.new affiliate.map(&:id)
      apply_tags candihash
      # Convert back to a list of results
      @results = candihash.results.reverse
  	end
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
  
  delegate :convert_ids, :timestamp, :list_type, :to => :"@affiliate"
  
  def affiliate browser = nil, params = nil
    @affiliate ||= browser
  end
  
  # Get the results of the current query from the affiliated browser.
  def result_ids
    affiliate.result_ids tags
  end
  
  def query_path
    "/collection"
  end
  
=begin
  def cur_page=(pagenum)
    affiliate.cur_page=( pagenum) if affiliate
  end
=end
  
  # If the entity has returned no results, suggest what the problem might have been
  def explain_empty
    explanation = affiliate.explain_empty tags
    (explanation[:sug] ? explanation[:report]+"<br>You might try #{explanation[:sug]}." : explanation[:report])+"<br>#{explanation[:hint]}"
  end
end

class UserSeeker < Seeker
  
  def datastore
    super.merge is_channel: (@is_channel || false)
  end
  
  def dataload datastr
    data = super
    @is_channel = data[:is_channel] || false
  end

  def affiliate browser=nil, params=nil
    @is_channel = (params[:channel]=="true") if params && params[:channel]
    unless @affiliate
      if @is_channel
        @affiliate = User.where("channel_referent_id > 0")
      else
        @affiliate = User.where("channel_referent_id = 0 AND sign_in_count > 0")
      end
      excluded_ids = @user.followee_ids + [@user.id, 4, 5] # Don't list guest, super, or the current user
      @affiliate = @affiliate.where("id not in (?) AND private != true", excluded_ids) unless [1, 3].include?(@user.id) # Show Max and Steve everything
    end
    @affiliate
  end

  def query_path
    "/users?channel="+@is_channel.to_s
  end
  
  def entity_name
    @is_channel ? "channel" : "user"
  end
  
  def table_header
    @is_channel ? "Available Channels" : "Possible Friends"
  end
  
  def convert_ids list
    User.where(id: list)
  end
  
  # Get the results of the current query.
  def apply_tags(candihash)
    # Rank/purge for tag matches
    neighbors = TagServices.lexical_similars(tags)
    weightings = TagServices.semantic_neighborhood(tag_ids = neighbors.map(&:id), 0.8)
    # Get tags that aren't in the original set
    (tags + Tag.where(id: weightings.keys - tag_ids)).each do |tag| 
      user_ids = tag.user_ids
      candihash.apply user_ids, weightings[tag.id] if tag.id > 0
      # candihash.apply tag.recipe_ids if tag.id > 0 # A normal tag => get its recipe ids and apply them to the results
      # Get candidates by matching the tag's name against recipe titles and comments
      users = affiliate.where("username ILIKE ?", "%#{tag.name}%")
      candihash.apply users.map(&:id), 1.0
      users = affiliate.where("about ILIKE ?", "%#{tag.name}%")
      candihash.apply users.map(&:id), 1.0
    end
  end
  
end

class ReferenceSeeker < Seeker
  
  # Get the results of the current query.
  def apply_tags(candihash)
    # Rank/purge for tag matches
    tags.each { |tag| 
      # candihash.apply tag.recipe_ids if tag.id > 0 # A normal tag => get its recipe ids and apply them to the results
      # Get candidates by matching the tag's name against recipe titles and comments
      candihash.apply affiliate.where("url LIKE ?", "%#{tag.name}%").map(&:id)
      constraints = @tagtype ? { tagtype: @tagtype } : {}
      # collect all the references of all the referents of all matching tags
      list = Tag.strmatch(tag.name).collect { |tag| tag.referents }.flatten
      list = list.collect { |referent| referent.reference_ids }
      candihash.apply list.flatten.uniq
    }
  end
end

class SiteSeeker < Seeker
  
  # Get the results of the current query.
  def apply_tags(candihash)
    # Rank/purge for tag matches
    tags.each { |tag| 
      # candihash.apply tag.recipe_ids if tag.id > 0 # A normal tag => get its recipe ids and apply them to the results
      # Get candidates by matching the tag's name against recipe titles and comments
      candihash.apply affiliate.where("site ILIKE ?", "%#{tag.name}%").map(&:id)
      # Find lexically-related tags of Source type and see if they point to sites
      # Find sites that have been tagged similarly
    }
  end
end

class TagSeeker < Seeker
  
  # Get the results of the current query.
  def result_ids
  	return @results if @results # Keeping a cache of results
    case tags.count
    when 0
      @results = (@tagtype ? affiliate.where(tagtype: @tagtype) : affiliate).map(&:id)
    when 1
      constraints = @tagtype ? { tagtype: @tagtype } : {}
      @results = Tag.strmatch(tags.first.name, constraints).map(&:id)
    else
      super
  	end
  end
  
  def apply_tags(candihash)
    # Rank/purge for tag matches
    tags.each { |tag| 
      # candihash.apply tag.recipe_ids if tag.id > 0 # A normal tag => get its recipe ids and apply them to the results
      # Get candidates by matching the tag's name against recipe titles and comments
      candihash.apply Tag.strmatch(tag.name, tagtype: tag.tagtype).map(&:id)
    }
  end
end

class FeedSeeker < Seeker
  
  def datastore
    super.merge all_feeds: (@all_feeds || false)
  end
  
  def dataload datastr
    data = super
    @all_feeds = data[:all_feeds] || false
  end
  
  def affiliate browser=nil, params=nil
    @all_feeds ||= params && params[:all_feeds]
    @affiliate ||= @all_feeds ? Feed.all : Feed.where(:approved => true)
  end
  
  # Get the results of the current query.
  def apply_tags(candihash)
    # Rank/purge for tag matches
    tags.each { |tag| 
      semantic_list = Feed.where(site_id: Site.where(referent_id: tag.referent_ids).map(&:id)).map(&:id)
      candihash.apply semantic_list
      # Get candidates by matching the tag's name against recipe titles and comments
      candihash.apply affiliate.where("description ILIKE ?", "%#{tag.name}%").map(&:id)
      candihash.apply affiliate.where("title ILIKE ?", "%#{tag.name}%").map(&:id)
    }
  end
end
