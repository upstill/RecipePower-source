# Class for a single selectable collection of recipes, whether physical or virtual
require 'my_constants.rb'
require "candihash.rb"
include ActionView::Helpers::DateHelper

class RcpBrowserElement
  attr_accessor :npages, :cur_page, :nodeid
  attr_reader :handle, :level
  @@nextid = 1  
  @@page_length = 20
  # Persisters for all browser-element nodes; these may be augmented by a subclass by
  # setting @persisters BEFORE handing off init to superclass
  @@persisters = [:selected, :handle, :nodeid, :userid, :cur_page]
  
  # Initialize a new element, either from supplied arguments or defaults
  def initialize(level, args)
    @persisters = (@@persisters + (@persisters || [])).uniq
    @level = level
    @persisters.each { |name| instance_variable_set("@#{name}", args[name]) if args[name] } if @persisters
    @selected = false unless @selected
    @handle = "Mystery Element" unless @handle
    @cur_page = @cur_page || 1
    unless @nodeid = args[:nodeid]
      @nodeid = @@nextid
      @@nextid = @@nextid + 1
    end
  end
  
  def timestamp recipe
    (cd = recipe.collection_date @userid) && "Cookmarked #{time_ago_in_words cd} ago."
  end
  
  def user
    @user || User.find(@userid)
  end
  
  # Class method to return a hash sufficient to reconstruct the element
  def save
    result = Hash[@persisters.map { |name| instance_variable_get("@#{name.to_s}") && [name, instance_variable_get("@#{name.to_s}")] }.compact]
    result[:classname] = self.class.name
    result
  end
  
  def css_class
    "RcpBrowser Level"+@level.to_s+(@selected ? " selected" : "")
  end
  
  # ID for uniquely selecting the element
  def css_id
    "RcpBrowserElement"+@nodeid.to_s
  end
  
  # The sources are a user, a list of users, or nil (for the master global list)
  def sources
    @userid
  end
  
  # The candidates are a list of recipes by id
  def candidates
    # Get a set of candidates, determined by:
    # -- who the owner of the list is 
    # -- who the viewer is
    # -- targetted status of the recipe (Rotation, etc.)
    # -- text to match against titles and comments
    @candidates = @candidates || Rcpref.recipe_ids( sources, @userid)
  end
  
  # Get the results of the current query.
  def result_ids(tagset)
  	return @results if @results # Keeping a cache of results
    if tagset.empty?
      @results = candidates
    else
      # We purge/massage the list only if there is a tags query here
      # Otherwise, we simply sort the list by mod date
      # Convert candidate array to a hash recipe_id=>#hits
      candihash = Candihash.new candidates
      source_set = sources
      
      # Rank/purge for tag matches
      tagset.each { |tag| 
          candihash.apply tag.recipe_ids if tag.id > 0 # A normal tag => get its recipe ids and apply them to the results
          # Get candidates by matching the tag's name against recipe titles and comments
          candihash.apply Rcpref.recipe_ids(source_set, 
                                          @userid,
                                          :status=>@status||MyConstants::Rcpstatus_misc,
                                          :comment=>tag.name) 
          # Get candidates that match specialtags in the title
          candihash.apply Rcpref.recipe_ids(source_set, 
                                            @userid,
                                            :status=>@status||MyConstants::Rcpstatus_misc,
                                            :title=>tag.name) 
      }
      # Convert back to a list of results
      @results = candihash.results(@rankings).reverse
  	end
  end
  
  # How many pages in the current result set?
  def npages(tagset)
    (self.result_ids(tagset).count+(@@page_length-1))/@@page_length
  end
  
  # Are there any recipes waiting to come out of the query?
  def empty?(tagset)
      self.result_ids(tagset).empty?
  end
  
  # Return a list of results based on the query tags and the paging parameters
  def results_paged(tagset)
    npg = npages tagset
    ids = result_ids tagset
    maxlast = ids.count-1 
    if npg <= 1
      first = 0
      last = maxlast
    else
      # Clamp current page to last page
      @cur_page = npg if @cur_page > npg
  
      # Now get indices of first and last records on the page
      first = (@cur_page-1)*@@page_length
      last = first+@@page_length-1
      last = maxlast if last > maxlast
    end
    ids[first..last].collect { |rid| Recipe.where( id: rid ).first }.compact
  end
  
  def select
    @selected = true
  end
  
  def deselect
    @selected = false
  end
  
  # Change the current selection to match the given id
  def select_by_id(id)
    @selected = (@nodeid == id)
  end
  
  # Returns the browser element that's selected, ACROSS THE TREE
  def selected
    @selected && self
  end
  
  # HTML for interpolating into the display
  def html(do_show)
    displaystyle = "display: "+(do_show ? "block" : "none" )+";"
    %Q{<div class="#{css_class}" id="#{css_id}" style="#{displaystyle}">
         #{'&nbsp'*@level}<a href="javascript:void(0)" >#{handle}</a>
       </div>}.html_safe
  end
  
end

# Class of composites, collections of browser elements
class RcpBrowserComposite < RcpBrowserElement
  attr_accessor :children
  
  # Save instance variables plus chidren
  def save
    result = super
    result[:children] = @children.map { |child| child.save } if @children
    result
  end
  
  def initialize(level, args)
    super
    @children = args[:children] ? 
      args[:children].map do |childargs|
        # For each child, determine its class, then create a new one, supplying its arguments
        childargs[:classname].constantize.new (level+1), childargs
      end
      : []
  end
  
  def select_by_id(id)
    super
    @children.each { |child| child.select_by_id(id) }
  end
  
  def selected
    unless (result = super)
      @children.each { |child| break if result = child.selected }
    end
    return result
  end

  # The HTML for the composite is just the HTML for the elements, joined with newlines
  def html(do_show)
    show_children = selected
    ([super(do_show || show_children)] + @children.map { |child| child.html(show_children) }).join("\n")
  end
  
end

# Element for all the recipes for a user (no children)
class RcpBrowserElementFriend < RcpBrowserElement
  
  def initialize(level, args)
    @persisters = (@persisters || []) << :friendid
    super
    @friendid = args[:friendid]
    @handle = User.find(@friendid).username
  end
  
  def sources
    @friendid
  end
  
  def candidates
    @candidates = @candidates || User.find(@friendid).recipes(public: true, sort_by: :collected)
  end
  
end

# Element for all the recipes for the owner, with subheads for status and favored keys
class RcpBrowserCompositeUser < RcpBrowserComposite
  
  def initialize(level, args)
    super
    @handle = "My Collection"
    if @children.empty?
      @children = [ MyConstants::Rcpstatus_rotation, 
        MyConstants::Rcpstatus_favorites, 
        MyConstants::Rcpstatus_interesting].map do |status| 
        args[:status] = status
        RcpBrowserElementStatus.new(level+1, args)
      end
    end
  end
  
  def candidates
    @candidates = @candidates || user.recipes(status: MyConstants::Rcpstatus_misc, sort_by: :collected)
  end

end

# Composite for all the recipes for the user's friends, with subheads for each friend
class RcpBrowserChannelsAndFriends < RcpBrowserComposite
  
  def initialize(level, args)
    super
    # Add a child node for each user being followed
    if @children.empty?
      klass = Module.const_get("User")
      if klass.is_a?(Class) # If User class is available (i.e., in Rails, as opposed to testing)
        args.delete :nodeid
        @children = user.follows(@isChannel).map do |followee| 
          args[:friendid] = followee.id
          RcpBrowserElementFriend.new level+1, args
        end
      end
    end
  end
  
  def sources
    user.follows(@isChannel).map { |followee| followee.id }
  end

=begin
  # Only need to override when we don't save friends
  def save
    saved = super
    # Don't save the children; they will be reconstructed from the database
    saved.delete(:children)
    saved
  end
=end
  
end

class RcpBrowserCompositeFriends < RcpBrowserChannelsAndFriends
  
  def initialize(level, args)
    @isChannel = false
    super
    @handle = "My Friends"
  end
  
end

# Element for all the recipes in a user's channels, with subheads for each channel
class RcpBrowserCompositeChannels < RcpBrowserChannelsAndFriends
  
  def initialize(level, args)
    @isChannel = true
    super
    @handle = "My Channels"
  end
  
end

# Element for all the recipes in a user's channels, with subheads for each channel
class RcpBrowserCompositeBlogs < RcpBrowserComposite
  
  def initialize(level, args)
    super
    @handle = "My Blogs"
  end
  
end

# Element for recent recipes 
class RcpBrowserElementRecent < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "Recent"
  end
  
  # Candidates for the Recent list are all recipes touched by the user
  def candidates
    user.recipes all: true
  end
  
  def timestamp recipe
    (td = recipe.touch_date @userid) && "Last viewed #{time_ago_in_words td } ago."
  end
  
end

# Element for a news feed for a particular user
class RcpBrowserElementNews < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "News Feed"
  end

end

# Element for a recipe list due to the status of a recipe
class RcpBrowserElementStatus < RcpBrowserElement
  
  def initialize(level, args)
    @persisters = (@persisters || []) << :status
    super
    @handle = MyConstants::Rcpstatus_names[@status]
  end
  
  def candidates
    @candidates = @candidates || user.recipes(status: @status, sort_by: :collected)
  end
  
end

# Element for a recipe list due to a tag
class RcpBrowserElementTaglist < RcpBrowserElement
  
  def initialize(level, args)
    super
    @tagid = args[:tagid]
    @handle = "Tag #{@tagid.to_s}"
  end

end

# Element for a recipe list for all the recipes in the system
class RcpBrowserElementAllRecipes < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "RecipePower&nbspCollection"
  end
  
  def sources
    nil
  end
  
end


# Top-level recipe browser, comprising the standard lists, and adding a tag list
class RcpBrowser < RcpBrowserComposite
  
  def initialize(userid_or_argshash)
    args = (userid_or_argshash.class.name == "Fixnum") ? { userid: userid_or_argshash } : userid_or_argshash
    @persisters = (@persisters || []) + [ :tagstxt, :specialtags ]
    super(0, args)
    @handle = ""
    @tagstxt = "" unless @tagstxt
    if @children.empty?
      userarg = { userid: args[:userid] }
      @children = [
        RcpBrowserCompositeUser.new(1, userarg),
        RcpBrowserCompositeFriends.new(1, userarg),
        RcpBrowserCompositeChannels.new(1, userarg),
        RcpBrowserCompositeBlogs.new(1, userarg),
        RcpBrowserElementAllRecipes.new(1, userarg),
        RcpBrowserElementRecent.new(1, userarg),
        RcpBrowserElementNews.new(1, userarg)
        ] 
    end
    @children[0].select unless selected # Ensure there's a selection
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
  
  # Uniquely, the top-level node collects a structure for itself and all
  # its children, then returns a YAML string
  def dump
    YAML::dump( save )
  end
  
  # Load the whole tree from a YAML string by restoring the structure, then
  # recreating the top-level tree. Handles uninitialized string
  def self.load(str)
    self.new YAML::load(str)
  end
  
  def html
    @children.map { |child| child.html(true) }.join("\n").html_safe
  end
  
  # Get the results of the current query.
  def result_ids
    selected.result_ids tags
  end
  
  def timestamp recipe
    selected.timestamp recipe
  end
  
  # How many pages in the current result set?
  def npages
    selected.npages tags
  end
  
  # Are there any recipes waiting to come out of the query?
  def empty?
    selected.result_ids(tags).empty?
  end
  
  # Return a list of results based on the paging parameters
  def results_paged
    selected.results_paged tags
  end
  
  def cur_page
    selected.cur_page
  end
  
  def cur_page=(pagenum)
    selected.cur_page= pagenum
  end
  
end
