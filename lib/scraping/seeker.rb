require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'

# A Seeker is an abstract class for a subclass which looks for a given item in the given stream
class Seeker
  attr_accessor :head_stream, :tail_stream, :token, :children
  attr_reader :value

  def initialize(head_stream, tail_stream, token = nil, children=[])
    if token.is_a?(Array)
      token, children = nil, token
    end
    @head_stream = head_stream
    @tail_stream = tail_stream
    @token = token
    @children = children || []
  end

  # Return a Seeker for a failed parsing attempt
  # The head_stream and tail_stream will denote the range scanned
  def self.failed head_stream, tail_stream=nil, token= nil, options={}
    if tail_stream.is_a? Hash
      tail_stream, token, options = nil, nil, tail_stream
    elsif tail_stream.is_a? Symbol
      tail_stream, token, options = nil, tail_stream, token
    end
    token, options = nil, token if token.is_a? Hash
    skr = self.new head_stream, (tail_stream || head_stream), token
    skr.instance_variable_set :@failed, true
    skr.instance_variable_set :@optional, options[:optional]
    skr.instance_variable_set :@enclose, options[:enclose]
    skr.children = options[:children]
    skr
  end

  # Find a place in the stream where we can match
  def self.seek stream, opts={}
    while stream.more?
      if sk = block_given? ? yield(stream) : self.match(stream, opts)
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

  # From a seeker tree, find those of the given token
  def find token=nil, &block
    results = @children&.map do |child|
      if block_given? ? block.call(child) : (child.token == token)
        child
      else
        child.find token, &block
      end
    end || []
    results.flatten.compact
  end

  # Return all the text enclosed by the scanner i.e., from the starting point of head_stream to the beginning of tail_stream
  def to_s
    head_stream.to_s tail_stream.pos
  end

  # Apply the results of the parse to the Nokogiri scanner
  def apply
    @children.each { |child| child.apply }
    head_stream.enclose_by_token_indices(@head_stream, @tail_stream, tag: @token) if @token
  end

  # Judge the success of a seeker by its consumption of tokens AND the presence of children
  def empty?
    (@head_stream == @tail_stream) && @children&.empty?
  end

  def consumed?
    # Did the result consume any tokens?
    @tail_stream.pos > @head_stream.pos
  end

  def encompass scanner
    @head_stream.encompass scanner
    @tail_stream.encompass scanner
    self
  end

  def traverse &block
    block.call self
    children && children.each do |child|
      child.traverse &block
    end
  end

  # Enclose the tokens of the seeker, from beginning to end, in a tag with the given class
  def enclose tagname='span'
    # Check that some ancestor doesn't already have the tag
    if @token && !head_stream.descends_from?(tagname, @token)
      @head_stream.enclose_to @tail_stream.pos, classes: @token, tag: tagname, value: @value
    end
  end

  # Recursively modify the Nokogiri tree to reflect seekers
  def enclose_all
    # The seeker reflects a successful parsing of the (subtree) scanner against the token.
    # Now we should modify the Nokogiri DOM to reflect the elements found
    traverse do |inner|
      if inner.token
        inner.enclose Parser.tag_for_token(inner.token)
      end
    end
  end

  # Match failed altogether
  def failed?
    @failed
  end

  def hard_fail?
    @failed && !@optional
  end

  def soft_fail?
    @failed && @optional
  end

  # Match succeeded; returns self for chaining purposes
  def success?
    self unless @failed # if @token || @children.present?
  end
  alias_method :if_succeeded, :'success?'

  def enclose? # Should the seeker be marked in an element, even without success?
    self if @enclose
  end
  alias_method :if_enclose, :'enclose?'

  def retain?
    self if !@failed || @enclose
  end
  alias_method :if_retain, :'retain?'

  # What's the next token to try? Three possibilities:
  # * The match succeeded: the next token is just after the match, i.e. @tail_stream
  # * the match failed: the next token is the successor of the present token, i.e. @head_stream.rest
  # * the match was optional: the tokens are consumed anyway: @head_stream.rest at a minimum, possibly @tail_stream
  def next context=nil
    subsq = if @failed
              if @optional
                @tail_stream.pos > @head_stream.pos ? @tail_stream : @head_stream.rest
              else
                @head_stream.rest
              end
            else # Success!
              @tail_stream
            end
    context ? subsq.encompass(context) : subsq
  end
end

# An Empty Seeker does nothing, and does not advance the stream
class EmptySeeker < Seeker
  def self.match stream, opts={}
    self.new stream, stream
  end
end

# A Null Seeker simply accepts the next string in the stream and advances past it
class NullSeeker < Seeker
  def self.match stream, opts={}
    self.new stream, stream.rest
  end
end

class StringSeeker < Seeker
  def self.match stream, options={}
    # TODO: the string should be tokenized according to tokenization rules and matched against a series of tokens
    self.new stream, stream.rest, options[:token] if stream.peek == options[:string]
  end
end

class RegexpSeeker < Seeker
  def self.match stream, options={}
    self.new stream, stream.rest, options[:token] if stream.peek&.match options[:regexp]
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

# Seek an ingredient list
class IngredientListSeeker < Seeker

  # Seek by probing for an ingredient spec at each newline
  def self.seek stream, opts={}
    ils = []
    while stream.more?
      if stream.peek == "\n" # Only seek at line boundaries
        if is = IngredientSpecSeeker.match(stream.rest)
          ils << is
        end
      end
    end
    if ils.present?
      # Package the stream from the first spec to the last as the ingredient list
    end
  end

end

# Seek a number at the head of the stream
class NumberSeeker < Seeker

  # A number can be a non-negative integer, a fraction, or the two in sequence
  def self.match stream, opts={}
    return self.new(stream, stream.rest(3), opts[:token]) if self.num3 stream.peek(3)
    return self.new(stream, stream.rest(2), opts[:token]) if self.num2 stream.peek(2)
    return self.new(stream, stream.rest, opts[:token]) if self.num1 stream.peek
  end

  # Is the string either an integer or a fraction?
  def self.num1 str
    str&.match(/^\d*\/{1}\d*$|^\d*[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]?$/) ||
        (str && self.num_word(str))
  end

  def self.fraction str
    str&.match(/^\d*\/{1}\d*$|^[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]$/)
  end

  def self.whole_num str
    str&.match(/^\d*$/) || (str && self.num_word(str))
  end

  # Does the string have an integer followed by a fraction?
  def self.num2 str
    str&.match /^\d*[ -](\d*\/{1}\d*|[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞])$|^\d*$/
  end

  # Does the string have an integer followed by a fraction?
  def self.num3 str
    return if str.blank?
    strs = str.split (/\ /)
    self.whole_num(strs.first) && strs[1] && %q{ and plus }.include?(strs[1]) && self.fraction(strs.last)
  end

  def self.num_word str
    (@NumWords ||= Hash[%w{ a an one two three four five six seven eight nine ten }.product([true])])[str.downcase]
  end

end

class TagSeeker < Seeker
  attr_reader :tagdata, :value

  def initialize(stream, next_stream, tagdata, token=nil)
    super stream, next_stream, token
    @value = tagdata[:name] if (@tagdata = tagdata).present?
  end

  def self.match stream, opts={}
    opts[:lexaur].chunk(stream) { |data, next_stream| # Find ids in the tags table
      # The Lexaur provides the data at sequence end, and the post-consumption stream
      scope = opts[:types] ? Tag.of_type(Tag.typenum opts[:types]) : Tag.all
      return unless tagdata = scope.limit(1).where(id: data).pluck( :id, :name).first
      tagdata = [:id, :name].zip(tagdata).to_h
      return self.new(stream, next_stream, tagdata, opts[:token])
    }
    nil
  end
end

# Conditions are a list of { process, }*. Similarly for Ingredients
class  TagsSeeker < Seeker
  attr_accessor :operand

  def self.match start_stream, opts={}
    children = []
    stream = start_stream
    operand = nil
    opts[:lexaur].match_list(stream) do |data, next_stream|
      # The Lexaur provides the data at sequence end, and the post-consumption stream
      scope = opts[:types] ? Tag.of_type(Tag.typenum opts[:types]) : Tag.all
      if tagdata = scope.limit(1).where(id: data).pluck( :id, :name).first
        rptype = { 'Ingredient' => :rp_ingname, 'Condition' => :rp_condition }[opts[:types]]
        children << TagSeeker.new(stream, next_stream, [:id, :name].zip(tagdata).to_h, rptype)
        operand = next_stream.peek
        stream = next_stream.rest
      else
        nil
      end
    end
    if children.present?
      result = self.new start_stream, children.last.tail_stream, opts[:token], children
      result.operand = operand
      result
    end
  end

=begin
  def self.match stream, opts
    # Get a series of zero or more tags of the given type(s), each followed by a comma and terminated with 'and' or 'or'
    if ns = TagSeeker.match(stream, opts.slice( :lexaur, :types))
      sk = self.new stream, ns.tail_stream, ns
      case ns.tail_stream.peek
      when 'and', 'or'
        # We expect a terminating condition
        if ns2 = TagSeeker.match(ns.tail_stream.rest, opts.slice(:lexaur, :types))
          sk.tag_seekers << ns2
          sk.tail_stream = ns2.tail_stream
        else
          return nil
        end
      when ','
        if further = self.match(ns.tail_stream.rest, opts)
          sk.tag_seekers += further.tag_seekers
          sk.tail_stream = further.tail_stream
        end
      end
      return sk
    end
  end
=end
end

# An Amount is a number followed by an optional amount, optionally followed by an alternative amount in parentheses
class AmountSeeker < Seeker

  attr_reader :num, :unit, :alt_num, :alt_unit

  def initialize stream, next_stream, num, unit
    super stream, next_stream
    @num = num
    @unit = unit
    @token = :rp_amt
  end

  def self.match stream, opts={}
    if num = NumberSeeker.match(stream)
      unit = TagSeeker.match num.tail_stream, opts.slice(:lexaur).merge(types: 5)
      self.new stream, (unit&.tail_stream || num.tail_stream), num, unit
    elsif stream.peek&.match(/(^\d*\/{1}\d*$|^\d*[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]?)(.*)/)
      num = $1
      unit = TagSeeker.match StrScanner.new([$2]), opts.slice(:lexaur).merge(types: 5)
      self.new(stream, stream.rest, num, unit) if unit
    end
  end
end

# Check for a matched set of parentheses in the stream and call a block on the contents
class ParentheticalSeeker < Seeker
  def self.match stream, opts={}
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

class ConditionsSeeker < TagsSeeker
  def self.match stream, opts
    super stream, opts.merge(types: 3)
  end
end

class IngredientsSeeker < TagsSeeker
  def self.match stream, opts
    super stream, opts.merge(types: 4)
  end
end

class IngredientSpecSeeker < Seeker
  attr_reader :amount, :condits, :ingreds

  def initialize stream, tail_stream, amount, condits, ingreds
    super stream, tail_stream
    @amount, @condits, @ingreds = amount, condits, ingreds
  end

  def self.match stream, opts={}
    original_stream = stream
    if amount = AmountSeeker.match(stream, opts)
      puts "Found amount #{amount.num} #{amount.unit}" if Rails.env.test?
      stream = amount.tail_stream
    end
    if condits = ConditionsSeeker.match(stream, opts)
      stream = condits.tail_stream
    end
    if ingreds = IngredientsSeeker.seek(stream, opts)
      self.new original_stream, ingreds.tail_stream, amount, condits, ingreds
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
