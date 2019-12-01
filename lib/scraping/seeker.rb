require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'

# A Seeker is an abstract class for a subclass which looks for a given item in the given stream
class Seeker
  attr_accessor :head, :rest

  def initialize(head_stream, rest_stream)
    @head = head_stream
    @rest = rest_stream
  end

  # Find a place in the stream where we can match
  def self.seek stream, opts={}
    while stream.more?
      if sk = self.match(stream, opts)
        return sk
      end
      stream = stream.rest
    end
  end

  # Seek to satisfy myself with the contents of the stream AT THIS POSITION.
  # Return: IFF there's a match, return an instance of the class, which denotes the original stream, and the
  #   rest of that stream, after parsing.
  def self.match stream, opts={}

  end
end

# A Null Seeker simply accepts the next string in the stream and advances past it
class NullSeeker < Seeker

  def self.match stream, opts={}
    self.new stream, stream.rest
  end
end

# Top-level Seeker: for a recipe
# We seek individual elements of the recipe, and when found, enclose them in an Element of that class.
# The following is the grammar implemented by this search.
# The CSS class denoting such an element is given in parentheses. All such elements
# are also marked with the rp_elmt class
# TODO: Author, Yield
# Ingredient list (rp_inglist): rp_ingspec*  An ingredient list is a sequence of ingredient specs
# Ingredient spec (rp_ingspec): [rp_amount]? [rp_presteps] [rp_ingname | rp_ingalts]+ [rp_ingcomment]?
# Ingredient amount (rp_amount): rp_num | rp_unit | (rp_num rp_unit) [rp_altamt]?
# Alternate amount (rp_altamt): \(rp_amt\)
# Steps before measurement (rp_presteps): rp_process [{,'or'} rp_process]*
# Process (rp_process): <Tag type: :Process>
# Ingredient name (rp_ingname): <Tag type: :Ingredient>
# Alternate ingredients (rp_ingalts): rp_ingname [',|or' rp_inglist]+
# List of ingredients (rp_inglist): rp_ingname [',|and' rp_ingname]+
# Ingredient comment (rp_ingcomment): <content to end of line>
# Amount number (rp_num): defined by NumberSeeker
# Amount unit (rp_unit): <Tag type: :Unit>

# Seek a number at the head of the stream
class NumberSeeker < Seeker

  # A number can be a non-negative integer, a fraction, or the two in sequence
  def self.match stream, opts={}
    return self.new(stream, stream.rest(2)) if stream.peek(2)&.match /^\d*[ -](\d*\/{1}\d*|[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞])$|^\d*$/
    return self.new(stream, stream.rest) if stream.peek&.match /^\d*\/{1}\d*$|^\d*[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]?$/
  end

end

class TagSeeker < Seeker
  attr_reader :tag_ids

  def initialize(stream, next_stream, tag_ids)
    super stream, next_stream
    @tag_ids = tag_ids
  end

  def self.match stream, lexaur, opts={}
    lexaur.chunk(stream) { |data, next_stream| # Find ids in the tags table
      # The Lexaur provides the data at sequence end, and the post-consumption stream
      tag_ids = Tag.of_type(opts[:types]).where(id: data).pluck :id
      return (self.new(stream, next_stream, tag_ids) if tag_ids.present?)
    }
  end
end

# An Amount is a number followed by an optional amount, optionally followed by an alternative amount in parentheses
class AmountSeeker < Seeker

  attr_reader :num, :unit, :alt_num, :alt_unit

  def initialize stream, next_stream, num, unit
    super stream, next_stream
    @num = num
    @unit = unit
  end

  def self.match stream, lexaur, opts={}
    if num = NumberSeeker.match(stream, lexaur)
      unit = TagSeeker.match num.rest, lexaur, types: 5
      self.new stream, (unit&.rest || num.rest), num, unit
    end
  end
end

# Check for a matched set of parentheses in the stream and call a block on the contents
class ParentheticalSeeker < Seeker
  def self.match stream, lexaur, opts={}
    if match = stream.peek.match(/^\(/)
      # Consume the opening paren
      # Look for the closing paren
      stream.next while stream.peak && !(match = stream.peek.match /^([^)]*)\)$/)
      # The last token may include the closing paren
      # Now we have a stream to present to the block
      if (found_inside = yield inner_stream)
      else
      end
    end
  end
end

# Conditions are a list of { process, }*. Similarly for Ingredients
class TagsSeeker < Seeker
  attr_accessor :tag_seekers

  def initialize stream, rest, tag_seeker
    super stream, rest
    @tag_seekers = [ tag_seeker ]
  end

  def self.match stream, lexaur, opts={}
    # Get a series of zero or more Process tags each followed by a comma
    if ns = TagSeeker.match(stream, lexaur, opts.slice(:types))
      sk = self.new stream, ns.rest, ns
      case ns.rest.peek
      when 'and'
        # We expect a terminating condition
        if ns2 = TagSeeker.match(ns.rest.rest, lexaur, opts.slice(:types))
          sk.tag_seekers << ns2
          sk.rest = ns2.rest
        else
          return nil
        end
      when ','
        if further = self.match(ns.rest.rest, lexaur)
          sk.tag_seekers += further.tag_seekers
          sk.rest = further.rest
        end
      end
      return sk
    end
  end
end

class ConditionsSeeker < TagsSeeker
  def self.match stream, lex
    super stream, lex, types: 3
  end
end

class IngredientsSeeker < TagsSeeker
  def self.match stream, lex
    super stream, lex, types: 4
  end
end

class IngredientSpecSeeker < Seeker
  attr_reader :amount, :condits, :ingreds

  def initialize stream, rest, amount, condits, ingreds
    super stream, rest
    @amount, @condits, @ingreds = amount, condits, ingreds
  end

  def self.match stream, lex
    original_stream = stream
    if amount = AmountSeeker.match(stream, lex)
      stream = amount.rest
    end
    if condits = ConditionsSeeker.match(stream, lex)
      stream = condits.rest
    end
    if ingreds = IngredientsSeeker.match(stream, lex)
      self.new original_stream, ingreds.rest, amount, condits, ingreds
    end
  end
end

=begin
require "candihash.rb"

class Seeker < Object

  # Save the Seeker data into session store
  def store
    # Serialize structure consisting of tagstxt and specialtags
    savestr = YAML::dump( datastore ) 
    back = YAML::load(savestr)
    savestr
  end
  
private

  def page_length
    25
  end

  # class-specific data storage
  def datastore
    { 
      :tagstxt => (@tagstxt || ""), 
      :tagtype => @tagtype, 
      :page => @cur_page || 1 # , :items_per_page => @items_per_page
    }
  end
  
  def dataload datastr
    prior = !datastr.blank? && YAML::load(datastr)
    if prior
      @tagstxt = prior[:tagstxt] || ""
      @tagtype = prior[:tagtype]
      @cur_page = prior[:page] || 1
      # @items_per_page = prior[:items_per_page] ? prior[:items_per_page].to_i : @@page_length
    else
      @tagstxt = "" 
      @tagtype = nil
      @cur_page = 1
      # @items_per_page = @@page_length
    end
    @items_per_page = page_length
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
  
  def convert_ids list, keep_ordering=false
    records = model_class.find(list)
    if keep_ordering
      records = records.group_by(&:id)
      list.map { |id| records[id].first }
    else
      records
    end
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
  
begin

  def cur_page=(pagenum)
    affiliate.cur_page=( pagenum) if affiliate
  end

end
  
  # If the entity has returned no results, suggest what the problem might have been
  def explain_empty
    explanation = affiliate.explain_empty tags
    (explanation[:sug] ? explanation[:report]+"<br>You might try #{explanation[:sug]}." : explanation[:report])+"<br>#{explanation[:hint]}"
  end

  private
  def page_length
    10
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
      @affiliate = @affiliate.collect { |u| [ u, u.recipes_collection_size ] }.sort { |u1, u2| u2.last <=> u1.last }.map(&:first)
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

  # Convert ids into User records, preserving the order of the list
  def convert_ids list
    records = User.find(list).group_by(&:id)
    list.map { |id| records[id].first }
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

class ListSeeker < Seeker

  def affiliate browser=nil, params=nil
    @affiliate ||= List.all
  end

  # Get the results of the current query.
  def apply_tags(candihash)
    # Rank/purge for tag matches
    tags.each { |tag|
      # Get candidates by matching the tag's name against recipe titles and comments
      candihash.apply affiliate.where("description ILIKE ?", "%#{tag.name}%").map(&:id)
      candihash.apply affiliate.where("title ILIKE ?", "%#{tag.name}%").map(&:id)
    }
  end
end
=end
