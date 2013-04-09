# Class for a single selectable collection of recipes, whether physical or virtual
require 'my_constants.rb'
require "candihash.rb"
include ActionView::Helpers::DateHelper

class Array
  # Loop through all elements of the array, finding and returning any that returns a result
  def poll 
    self.each { |elmt| 
      if val = yield(elmt)
        return val
      end
    }
    nil
  end
end

class BrowserElement
  attr_accessor :npages, :cur_page, :visible
  attr_reader :handle, :level
  @@page_length = 20
  # Persisters for all browser-element nodes; these may be augmented by a subclass by
  # setting @persisters BEFORE handing off init to superclass
  @@persisters = [:selected, :handle, :userid, :cur_page]
  
  # Initialize a new element, either from supplied arguments or defaults
  def initialize(level, args)
    @persisters = (@@persisters + (@persisters || [])).uniq
    @level = level
    @persisters.each { |name| instance_variable_set("@#{name}", args[name]) if args[name] } if @persisters
    @selected = false unless @selected
    @handle = "Mystery Element" unless @handle
    @cur_page = @cur_page || 1
  end
  
  def content_name
    self.class.to_s
  end
  
  def guide()
    "This is a browser element "+self.class.to_s
  end
  
  # The server callback to add an element of this type
  def add_path
    nil
  end
  
  # By default, browser elements are ready for refresh immediately
  def refresh
    true
  end
  
  # The javascript call to delete an element of this type
  def delete_path
    nil
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
    "RcpBrowser Level"+@level.to_s+(@selected ? " active" : "")
  end
  
  # ID for uniquely selecting the element
  def css_id
    self.class.to_s
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
  
  # Are there any recipes waiting to come out of the query?
  def empty?(tagset)
      self.result_ids(tagset).empty?
  end
  
=begin
  # How many pages in the current result set?
  def npages(tagset)
    (self.result_ids(tagset).count+(@@page_length-1))/@@page_length
  end

  # Return a list of results based on the query tags and the paging parameters
  def results_paged tagset
    npg = npages tagset
    ids = result_ids tagset
    first = 0
    ixbound = ids.count 
    if npg > 1
      # Clamp current page to last page
      @cur_page = npg if @cur_page > npg
      # Now get index bounds for the records on the page
      first = (@cur_page-1)*@@page_length
      last = first+@@page_length
      ixbound = last if ixbound > last
    end
    convert_ids ids[first...ixbound]
  end
=end
  
  def convert_ids list
    list.collect { |rid| Recipe.where( id: rid ).first }.compact
  end
  
  def select
    @selected = true
  end
  
  def deselect
    @selected = false
  end
  
  # Change the current selection to match the given id
  def select_by_id(id)
    @selected = (id==css_id)
  end
  
  # Select a node based on its content (user, channel or feed)
  def find_by_content(obj)
    nil
  end
  
  # Method to insert a new node representing a list (feed, friend, etc.)
  # Only makes sense if overridden by a composite node
  def add_by_content obj
  end
  
  # Returns the browser element that's selected, ACROSS THE TREE
  def selected
    @selected && self
  end
  
  # Used to gather a list of all nodes in the tree and tag each for display
  def node_list do_show=false
    @visible = do_show
    [self]
  end
  
  def list_type
    :recipe
  end
  
end

class RcpBrowserElement < BrowserElement
end

# Class of composites, collections of browser elements
class BrowserComposite < BrowserElement
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
  
  # Recursive search for the selected child
  def selected
    result = super || (@children.poll { |child| child.selected })
  end
  
  # Find the child with the associated content
  def find_by_content obj
    @children.poll { |child| child.find_by_content obj }
  end
  
  def add_by_content obj
    @children.poll { |child| child.add_by_content obj }
  end
  
  def node_list do_show=false
    show_children = selected
    super(do_show || show_children) + @children.collect { |child| child.node_list show_children }.flatten
  end
  
  def delete_selected_child
    @children.each_index { |ix| 
      child = @children[ix]
      if selected = child.selected
        # Some child in this subtree is selected
        if selected == child # Direct selection => we are this child's parent
          @children.delete child
          if @children[ix]
            @children[ix].select
          elsif ix > 0
            @children[ix-1].select
          else
            select
          end
        else
          child.delete_selected_child
        end
        break
      end
    }
  end
  
end

class RcpBrowserComposite < BrowserComposite
end

# Element for all the entries for a feed
class FeedBrowserElement < BrowserElement
  attr_accessor :feedid
  
  def initialize(level, args)
    @persisters = (@persisters || []) << :feedid
    super
    @feedid = args[:feedid] || args[:feed].id
    @handle = (args[:feed] || Feed.find(@feedid)).title
  end
  
  def guide
    "These are the most recent posts from '#{Feed.find(@feedid).title}'.<br>You can remove a feed by clicking the 'X' next to its name."
  end
  
  def hints
    "If there are no posts, the feed may have dried up. Nothing to see here, time to move on..."
  end
  
  def sources
    @feedid
  end
  
  # IDs of feed entries consistent with the tag set
  def result_ids tagset 
    Feed.find(@feedid).entry_ids
  end

  def convert_ids list
    list.collect { |id| FeedEntry.where( id: id ).first }.compact
  end
  
  def list_type
    :feed
  end
  
  def updated_at
    Feed.find(@feedid).updated_at
  end
  
  # Refresh in background, returning false to indicate a wait state
  def refresh
    feed = Feed.find(@feedid)
    feed.refresh
    false
  end
  
  def find_by_content obj
    (obj.kind_of? Feed) && 
    (obj.id == @feedid) && 
    self
  end
  
  def delete_path
    "/feeds/#{@feedid}/remove"
  end
  
  def css_id
    self.class.to_s+@feedid.to_s
  end
  
end

# Element for all the recipes in a user's channels, with subheads for each channel
class FeedBrowserComposite < BrowserComposite
  
  def initialize(level, args)
    super
    @handle = "My Feeds"
    if @children.empty?
      klass = Module.const_get("User")
      if klass.is_a?(Class) # If User class is available (i.e., in Rails, as opposed to testing)
        args[:selected] = false
        @children = user.feed_ids.map do |id| 
          args[:feedid] = id
          FeedBrowserElement.new level+1, args
        end
      end
    end
  end
  
  def guide()
    "Here is where you see the posts from <strong>all</strong> your feeds in one place.<br>Add more feeds by clicking the '+'."
  end
  
  def hints()
    "Otherwise, click into the individual feeds to see what's up."
  end
  
  def content_name
    "Feeds"
  end
  
  def add_path
    "/feeds"
  end
  
  def add_by_content obj
    if (obj.kind_of? Feed)
      @children.unshift(new_elmt = FeedBrowserElement.new(@level+1, { feed: obj, userid: user.id }))
      new_elmt
    end 
  end

  def convert_ids list
    list.collect { |id| FeedEntry.where( id: id ).first }.compact
  end
  
  # Collect feed entries from the children
  def result_ids tagset
    Feed.entry_ids user.feed_ids
  end
  
  def list_type
    :feed
  end
  
end

# Element for all the recipes for a user (no children)
class RcpBrowserElementFriend < BrowserElement
  
  def initialize(level, args)
    @persisters = (@persisters || []) << :friendid
    super
    @friendid = args[:friendid]
    @handle = User.find(@friendid).handle
  end
  
  def sources
    @friendid
  end
  
  def timestamp recipe
    (cd = recipe.collection_date @friendid) && "Cookmarked #{time_ago_in_words cd} ago."
  end
  
  def candidates
    @candidates = @candidates || User.find(@friendid).recipes(public: true, sort_by: :collected)
  end
  
  def css_id
    self.class.to_s+@friendid.to_s
  end
  
  def find_by_content obj
    (obj.kind_of? User) && 
    (obj.id == @friendid) && 
    self
  end
  
  def delete_path
    "/users/#{@friendid}/remove"
  end
  
  def guide
    User.find(@friendid).channel? ?
    "These are the recipes from the #{@handle} channel.<br>Withdraw from the channel by clicking the 'X' next to the name." :
    "These are all the recipes collected by #{@handle}.<br>Tired of their friendship? Click the 'X' next to the name."
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
  
  def guide()
    "This is where all your cookmarks live. The subheads are for your most important selections."
  end
  
  def hints()
    "It doesn't look like you've cookmarked any recipes. You'll never get dinner on the table at this rate!"+
    "<br>How about browsing through your Friends' recipes or one of your Channels and grabbing some of those? Or click on the RecipePower Collection and search through that?"+
    "<br>Or even, dare we say it, head off to the Wide Wild Web and cookmark some findings there? (You <strong>do</strong> have the browser button installed, right?)"
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
        @children = user.follows(@isChannel).map do |followee| 
          args[:friendid] = followee.id
          RcpBrowserElementFriend.new level+1, args
        end
      end
    end
  end
  
  def add_path
    "/users?channel=#{@isChannel.to_s}"
  end
  
  def add_by_content obj
    if (obj.kind_of? User) && (obj.channel? == @isChannel)
      @children.unshift(new_elmt = RcpBrowserElementFriend.new(@level+1, { user: obj, friendid: obj.id }))
      new_elmt
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
  
  def content_name
    "Friends"
  end
  
  def guide()
    "Here is where you see the recipes from all your friends in one place, ready for browsing or searching.<br>Feeling friendly? Look for more friends by clicking the '+'."
  end
  
  def hints()
    "Are your friends useless? Do you even <strong>have</strong> any friends? Get some (more) today!"
  end
  
end

# Element for all the recipes in a user's channels, with subheads for each channel
class RcpBrowserCompositeChannels < RcpBrowserChannelsAndFriends
  
  def initialize(level, args)
    @isChannel = true
    super
    @handle = "My Channels"
  end
  
  def content_name
    "Channels"
  end
  
  def guide()
    "Here is where you see the recipes from all your channels in one place.<br>Browse for more channels by clicking the '+'."
  end
  
  def hints()
    ""
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
  
  def guide()
    "Here is where you see the recipes you've visited most recently."
  end
  
  def hints()
    "You obviously haven't been here long: this list will fill up quickly as you look around in RecipePower."
  end
  
end

# Element for a news feed for a particular user
class RcpBrowserElementNews < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "News Feed"
  end
  
  def guide()
    "Here is where you get news flashes from your friends and channels"
  end
  
  def hints()
    "Your friends could be boring, or maybe you need more friends (channels). Click over to My Friends or My Channels to get more."
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
  
  def css_id
    self.class.to_s+@status.to_s
  end
  
  def guide()
    case @status
    when MyConstants::Rcpstatus_rotation
      "'#{@handle}' is for recipes that you're making on a regular basis."
    when MyConstants::Rcpstatus_favorites
      "'#{@handle}' are your tried-and-true favorites."
    when MyConstants::Rcpstatus_interesting
      "'#{@handle}' earmarks recipes for auditioning ASAP."
    end
  end
  
  def hints()
    "Once you've collected a recipe, add it to this list by poking the '#{@handle}' button while editing it."
  end
  
end

# Element for a recipe list due to a tag
class RcpBrowserElementTaglist < RcpBrowserElement
  
  def initialize(level, args)
    super
    @tagid = args[:tagid]
    @handle = "Tag #{@tagid.to_s}"
  end
  
  def css_id
    self.class.to_s+@tagid.to_s
  end

end

# Element for a recipe list for all the recipes in the system
class RcpBrowserElementAllRecipes < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "RecipePower Collection"
  end
  
  def sources
    nil
  end
  
  def guide()
    "These are <strong>all</strong> the recipes that have been collected in RecipePower."
  end
  
end

# Top-level recipe browser, comprising the standard lists, and adding a tag list
class ContentBrowser < BrowserComposite
  
  def initialize(userid_or_argshash)
    args = (userid_or_argshash.class.name == "Fixnum") ? { userid: userid_or_argshash } : userid_or_argshash
    @persisters = @persisters || []
    super(0, args)
    @handle = ""
    if @children.empty?
      userarg = { userid: args[:userid] }
      @children = [
        RcpBrowserCompositeUser.new(1, userarg),
        RcpBrowserCompositeFriends.new(1, userarg),
        RcpBrowserCompositeChannels.new(1, userarg),
        FeedBrowserComposite.new(1, userarg),
        RcpBrowserElementAllRecipes.new(1, userarg),
        RcpBrowserElementRecent.new(1, userarg),
        RcpBrowserElementNews.new(1, userarg)
        ] 
    end
    @children[0].select unless selected # Ensure there's a selection
  end
  
  # Remove the currently-selected element and select an appropriate new one: either 1) the next sibling, 2) the previous sibling, or 3) the parent
  def delete_selected
    delete_selected_child
  end
  
  # Uniquely, the top-level node collects a structure for itself and all
  # its children, then returns a YAML string
  def dump
    YAML::dump( save )
  end
  
  # Load the whole tree from a YAML string by restoring the structure, then
  # recreating the top-level tree. Handles uninitialized string
  def self.load(str)
    !str.blank? && self.new(YAML::load(str))
  end
  
  def node_list
    @children.collect { |child| child.node_list true }.flatten
  end
  
  def convert_ids list
    selected.convert_ids list
  end
  
  # Get the results of the current query.
  def result_ids tags
    selected.result_ids tags
  end
  
  # Return the timestamp for the given list tlement (generally, a recipe)
  def timestamp obj
    selected.timestamp obj
  end
  
  # Report the time this content was last updated
  def updated_at
    selected.respond_to?(:updated_at) && selected.updated_at
  end
  
  # Update this content. Return true if it's ready now, false if we have to wait for completion
  def refresh
    selected.refresh
  end
  
  # How many pages in the current result set?
  def npages tags
    selected.npages tags
  end
  
  # Are there any recipes waiting to come out of the query?
  def empty? tags
    selected.result_ids(tags).empty?
  end
  
  # Return a list of results based on the paging parameters
  def results_paged tags
    selected.results_paged tags
  end
  
  # If the collection has returned no results, suggest what the problem might have been
  def explain_empty tags
    report = "It looks like #{selected.handle} doesn't have anything that matches your search."
    hint = ""
    case tags.count
    when 0
      sug = nil
      hint = selected.hints
    when 1
      sug = "a different tag or no tags at all up there"
    else
      sug = "removing a tag up there"
    end
    if selected.class.to_s =~ /Composite/ 
      if selected.children.empty?
        verb = selected.content_name == "Friends" ? "picked" : "subscribed to"
        report = "There's no content here because you haven't #{verb} any #{selected.content_name}."
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
    sug ? report+"<br>You might try #{sug}." : report
    { sug: sug, report: report, hint: hint }
  end
  
  def cur_page
    selected.cur_page
  end
  
  def cur_page=(pagenum)
    selected.cur_page= pagenum
  end
  
  def list_type
    selected.list_type
  end
  
  # Select the browswer element corresponding to the given object
  def select_by_content obj
    old_selection = selected
    new_selection = find_by_content(obj) || add_by_content(obj)
    if new_selection && (old_selection != new_selection)
      old_selection.deselect if old_selection
      new_selection.select
    end
    new_selection
  end
end
