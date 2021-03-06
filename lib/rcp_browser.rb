=begin
# Class for a single selectable collection of entities, whether physical or virtual
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
  attr_accessor :visible, :handle
  attr_reader :level, :classed_as
  # Persisters for all browser-element nodes; these may be augmented by a subclass by
  # setting @persisters BEFORE handing off init to superclass
  @@persisters = [:selected, :handle, :userid]

  # Initialize a new element, either from supplied arguments or defaults
  def initialize(level, args={})
    @persisters = (@@persisters + (@persisters || [])).uniq
    @level = level
    @persisters.each { |name| instance_variable_set("@#{name}", args[name]) if args[name] } if @persisters
    @selected = false unless @selected
    @classed_as = :public
  end

  def handle extend=false
    @handle ||= "Mystery Element"
  end
  
  def content_name
    self.class.to_s
  end
  
  def content_empty_report
     ""
  end
  
  def popup_text
    guide
  end
  
  def guide
    "This is a browser element "+self.class.to_s
  end
  
  def hints
    nil
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
    @user ||= User.find(@userid)
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
  
  # Filter a set of candidate ids using one tag
  def apply_tag tag, source_set, candihash
    # Default procedure, for recipes
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
  end
  
  # Get the results of the current query. This is a generic method for applying a list of tags to an
  # abstract type of result. Short of changing the algorithm, it is made specific by overriding apply_tag, 
  # above
  def result_ids(tagset = [])
  	return @results if @results && (tagset == @tagset) # Keeping a cache of results for a given tagset
    if tagset.empty?
      @tagset = tagset
      @results = candidates
    else
      # We purge/massage the list only if there is a tags query here
      # Otherwise, we simply sort the list by mod date
      # Convert candidate array to a hash recipe_id=>#hits
      candihash = Candihash.new candidates
      source_set = sources
      
      # Rank/purge for tag matches
      tagset.each { |tag| apply_tag tag, source_set, candihash }
      # Convert back to a list of results
      @tagset = tagset
      @results = candihash.results(@rankings).reverse
  	end
  	@results
  end
  
  # By default, all recipes show
  def should_show(recipe)
    true
  end
  
  # Are there any recipes waiting to come out of the query?
  def empty?(tagset)
      self.result_ids(tagset).empty?
  end
  
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

  # Change the current selection to match the given id
  def find_by_id(id)
    self if id==css_id
  end

  # Select a node based on its content (user, channel or feed)
  def find_by_content(obj)
    nil
  end
  
  # Method to insert a new node representing a list (feed, friend, etc.)
  # Only makes sense if overridden by a composite node
  def add_by_content obj
  end
  
  # Find function for the parent of a given node. Elements need not apply
  def parent_of node
    nil
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

private  
  # The candidates are a list of recipes by id
  def candidates
    # Get a set of candidates, determined by:
    # -- who the owner of the list is 
    # -- who the viewer is
    # -- targetted status of the recipe (Rotation, etc.)
    # -- text to match against titles and comments
    @candidates ||= Rcpref.recipe_ids( sources, @userid)
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
      args[:children].collect { |childargs|
        # For each child, determine its class, then create a new one, supplying its arguments
        begin
          childargs[:classname].constantize.new (level+1), childargs
        rescue
          nil
        end
      }.compact
      : []
  end
  
  def content_empty_report
     ((children.count < 2) ? "This "+content_name.singularize+" doesn't" : "These "+content_name+" don't")+" appear to have any content."
  end

  def select_by_id(id)
    super
    @children.each { |child| child.select_by_id(id) }
  end

  def find_by_id(id)
    super || @children.find { |child| child.find_by_id(id) }
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
  
  # Find function for the parent of a given node. Elements need not apply
  def parent_of node
    @children.poll { |child| (child == node) ? self : child.parent_of(node) }
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
    @persisters = (@persisters || [])
    @persisters << :feedid
    super
    @feedid = args[:feedid]
  end
  
  def handle extend=false
    @handle ||= Feed.find(@feedid).title
  end
  
  def popup_text
    "Posts from the feed '#{Feed.find(@feedid).title}'."
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
  # def result_ids tagset 
    # Feed.find(@feedid).entry_ids
  # end

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
    feed.perform
    true
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
  
  # Get the results of the current query. This is a generic method for applying a list of tags to an
  # abstract type of result. Short of changing the algorithm, it is made specific by overriding apply_tag, 
  # above
  def result_ids(tagset = [])
  	return @results if @results && (tagset == @tagset) # Keeping a cache of results for a given tagset
  	matches = candidates
    tagset.each do |tag|
      matches = matches.where "name ILIKE ? OR summary ILIKE ? OR url ILIKE ?", 
        "%#{tag.name}%", "%#{tag.name}%", "%#{tag.name}%"
  	end
    @tagset = tagset
  	@results = matches.map(&:id)
  end

private  
  def candidates
    @candidates ||= FeedEntry.where(feed_id: @feedid).order('published_at DESC')
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
  
  def popup_text
    "All the feeds you've signed up for."
  end
  
  def guide
    "Here is where you see the posts from <strong>all</strong> your feeds in one place.<br>Add more feeds by clicking the '+'."
  end
  
  def hints
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
  
  # Get the results of the current query. This is a generic method for applying a list of tags to an
  # abstract type of result. Short of changing the algorithm, it is made specific by overriding apply_tag, 
  # above
  def result_ids(tagset = [])
  	return @results if @results && (tagset == @tagset) # Keeping a cache of results for a given tagset
  	matches = candidates
    tagset.each do |tag|
      matches = matches.where "name ILIKE ? OR summary ILIKE ? OR url ILIKE ?", 
        "%#{tag.name}%", "%#{tag.name}%", "%#{tag.name}%"
  	end
    @tagset = tagset
  	@results = matches.map(&:id)
  end
  
  def list_type
    :feed
  end

private  
  def candidates
    @candidates ||= FeedEntry.where feed_id: user.feed_ids
  end
  
end

# Element for all the recipes for a user (no children)
class RcpBrowserElementFriend < BrowserElement
  
  def initialize(level, args)
    @persisters = (@persisters || [])
    @persisters << :friendid
    super
    @friendid = args[:friendid]
  end

  def classed_as
    # Channels are public
    user.channel? ? :public : :friends
  end
  
  def handle extend=false
    @handle ||= user.handle
    extend ?
        ((classed_as == :public) ? "The <strong>#{@handle}</strong> Collection" : "The Collected Cookmarks of <strong>#{@handle}</strong>").html_safe :
        @handle
  end
  
  def sources
    @friendid
  end
  
  def timestamp recipe
    (cd = recipe.collection_date @friendid) && "Cookmarked #{time_ago_in_words cd} ago."
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
  
  def popup_text
    if user.channel?
      "Recipes collected in the channel '#{handle}'."
    else
      "The collection of user '#{handle}'."
    end
  end
  
  def guide
    if user.channel?
      "These are the recipes from the #{handle} channel.<br>Withdraw from the channel by clicking the 'X' next to the name."
    else
      "These are all the recipes collected by #{handle}.<br>Tired of their friendship? Click the 'X' next to the name."
    end
  end
  
  def hints
    "Not much to do about that..."
  end

  def user
    @user ||= User.find @friendid
  end

  private

  def candidates
    @candidates ||= user.recipe_ids_g(public: true, sort_by: :collected)
  end

end

# Element for all the recipes for the owner, with subheads for status and favored keys
class RcpBrowserCompositeUser < RcpBrowserComposite
  
  def initialize(level, args)
    super
    @level = level
    @handle = "All My Cookmarks"
    @classed_as = :personal
    if @children.empty?  # Default, in case never saved before, or rebuilding browser
begin

      @children = [ MyConstants::Rcpstatus_rotation,
        MyConstants::Rcpstatus_favorites, 
        MyConstants::Rcpstatus_interesting].map do |status| 
        args[:status] = status
        RcpBrowserElementStatus.new(level+1, args)
      end

end
      klass = Module.const_get("User")
      if klass.is_a?(Class) # If User class is available (i.e., in Rails, as opposed to testing)
        @children += user.collection_tags.map do |tag|
          args[:tagid] = tag.id
          RcpBrowserElementTaglist.new level+1, args
        end
      end
    end
  end

  # Add a collection by reference to a tag
  def add_by_content tag
    if found = find_by_content(tag)
      return found
    end
    child = (tag.tagtype == 16) ?
        RcpBrowserElementList.new(@level+1, tagid: tag.id, userid: @userid) :
        RcpBrowserElementTaglist.new(@level+1, tagid: tag.id, userid: @userid)
    @children << child
    child
  end

  def should_show(recipe)
    recipe.cookmarked(user.id)
  end
  
  def guide
    "This is where all your cookmarks live. The subheads are for your most important selections."
  end
  
  def popup_text
    "This is where all your cookmarks live."
  end
  
  def content_empty_report()
    "It doesn't look like you've cookmarked any recipes. You'll never get dinner on the table at this rate!"
  end
  
  def hints 
    "<br>How about browsing through your Friends' recipes or one of your Channels and grabbing some of those? Or click on The Big List and search through that?"+
    "<br>Or even, dare we say it, head off to the Wild World Web and cookmark some findings there? (...after installing the Cookmark Button of course...)"
  end

  def add_path
    "/collection/new?modal=true"
  end

private
  def candidates
    @candidates ||= user.recipe_ids_g # (status: MyConstants::Rcpstatus_misc, sort_by: :collected)
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
        @children = user.follows(@is_channel).map do |followee| 
          args[:friendid] = followee.id
          RcpBrowserElementFriend.new level+1, args
        end
      end
    end
  end
  
  def add_path
    "/users?channel=#{@is_channel.to_s}"
  end
  
  def add_by_content obj
    if (obj.kind_of? User) && (obj.channel? == @is_channel)
      @children.unshift(new_elmt = RcpBrowserElementFriend.new(@level+1, { user: obj, friendid: obj.id }))
      new_elmt
    end 
  end
  
  def sources
    user.follows(@is_channel).map { |followee| followee.id }
  end
end

class RcpBrowserCompositeFriends < RcpBrowserChannelsAndFriends
  
  def initialize(level, args)
    @is_channel = false
    super
    @handle = "All Friends' Cookmarks"
    @classed_as = :friends
  end
  
  def content_name
    "Friends"
  end
  
  def popup_text
    "The collections of all your friends."
  end
  
  def guide
    "Here is where you see the recipes from all your friends in one place, ready for browsing or searching.<br>Feeling friendly? Look for more friends by clicking the '+'."
  end
  
  def hints
    "Are your friends useless? Do you even <strong>have</strong> any friends? Get some (more) today!"
  end
  
end

# Element for all the recipes in a user's channels, with subheads for each channel
class RcpBrowserCompositeChannels < RcpBrowserChannelsAndFriends
  
  def initialize(level, args)
    @is_channel = true
    super
    @handle = "All My Public Collections"
  end
  
  def content_name
    "Channels"
  end
  
  def popup_text
    "All the recipes from all your channels."
  end
  
  def guide
    "Here is where you see the recipes from all your channels in one place.<br>Browse for more channels by clicking the '+'."
  end
  
  def hints
    ""
  end

  private
  # The candidates are a list of recipes by id
  def candidates
    # Get a set of candidates, determined by:
    # -- who the owner of the list is
    # -- who the viewer is
    # -- targetted status of the recipe (Rotation, etc.)
    # -- text to match against titles and comments
    # @candidates ||= Rcpref.recipe_ids( sources, @userid)
    @candidates ||= User.find(sources).collect { |user| user.recipe_ids_g }.flatten.uniq
  end

end

# Element for recent recipes 
class RcpBrowserElementRecent < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "Recently Viewed"
    @classed_as = :personal
  end
  
  def timestamp recipe
    (td = recipe.touch_date @userid) && "Last viewed #{time_ago_in_words td } ago."
  end
  
  def popup_text
    "What you've cookmarked or looked at most recently."
  end
  
  def guide
    "The recipes you've visited most recently."
  end
  
  def hints
    "You obviously haven't been here long: this list will fill up quickly as you look around in RecipePower."
  end

private
  # Candidates for the Recent list are all recipes touched by the user
  def candidates
    user.recipe_ids_g all: true
  end
  
end

# Element for a news feed for a particular user
class RcpBrowserElementNews < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "News Feed"
  end
  
  def popup_text
    "The latest happenings from your friends and channels"
  end
  
  def guide
    "Here is where you get news flashes from your friends and channels"
  end
  
  def hints
    "Your friends could be boring, or maybe you need more friends (channels). Click over to My Friends or My Channels to get more."
  end

end

# Element for a recipe list due to the status of a recipe
class RcpBrowserElementStatus < RcpBrowserElement
  
  def initialize(level, args)
    @persisters = (@persisters || []) << :status
    super
    @handle = I18n.t MyConstants::Rcpstatus_names[@status]
    @classed_as = :personal
  end

  def handle extend=false
    extend ? "My <strong>#{@handle}</strong> Collection".html_safe : @handle
  end
  
  def should_show(recipe)
    recipe.cookmarked(user.id) && (recipe.status <= @status)
  end
  
  def css_id
    self.class.to_s+@status.to_s
  end
  
  def popup_text
    case @status
    when MyConstants::Rcpstatus_rotation
      "Recipes that you're making on a regular basis."
    when MyConstants::Rcpstatus_favorites
      "Your tried-and-true favorites."
    when MyConstants::Rcpstatus_interesting
      "Earmarked for auditioning sooner or later."
    end
  end
  
  def guide
    case @status
    when MyConstants::Rcpstatus_rotation
      "'#{handle}' is for recipes that you're making on a regular basis."
    when MyConstants::Rcpstatus_favorites
      "'#{handle}' are your tried-and-true favorites."
    when MyConstants::Rcpstatus_interesting
      "'#{handle}' earmarks recipes for auditioning sooner or later."
    end
  end

private  
  def candidates
    @candidates = @candidates || user.recipe_ids_g(status: @status, sort_by: :collected)
  end
  
end

# Element for a recipe list for all the recipes in the system
class RcpBrowserElementAllRecipes < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "Every Cookmark There Is"
  end
  
  def sources
    nil
  end
  
  def popup_text
    "All the recipes that have been collected in RecipePower."
  end
  
  def guide
    "These are all the recipes that have been collected in RecipePower."
  end
  
end

# Top-level recipe browser, comprising the standard lists, and adding a tag list
class ContentBrowser < BrowserComposite
  
  def initialize(userid_or_argshash)
    args = (userid_or_argshash.class.name == "Integer") ? { userid: userid_or_argshash } : userid_or_argshash
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
  
  # Take heed of any relevant incoming parameters
  def apply_params params=nil
    if params
      if params[:selected]
        # Validate the new selection before setting it, so we don't wind up with a nil selection
        if self.find_by_id params[:selected]
          self.select_by_id params[:selected]
          true # Browser has changed (=> maybe we want to save it?)
        else
          raise Exception, "Apparently that #{params[:selected][0..3]} is missing in action"
        end
      end
    end
  end
    
  
  # Should a recipe be seen in the current browser? This is for updating a list based on changes to the recipe, including:
  # -- removing from a user's collection
  # -- changing tags on the recipe
  # -- changing the recipe's status
  def should_show(recipe)
    selected.should_show recipe
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

  # Return the css_id for the composite of the given type
  def id_for which
    case which
      when :personal
        "RcpBrowserCompositeUser"
      when :friends
        "RcpBrowserCompositeFriends"
      when :public
        "RcpBrowserCompositeChannels"
    end
  end

  def node_list which = nil
    id = id_for which
    parent = id ? find_by_id(id) : self
    parent.children.collect { |child| child.node_list true }.flatten
  end

begin

  def selected_is_under which
    id = id_for which
    (selected.css_id == id) || (parent_of(selected).css_id == id) ||
        (which == :personal) && (selected.css_id == "RcpBrowserElementRecent") ||
        (which == :public) && (selected.css_id == "RcpBrowserElementAllRecipes")
        case which
          when :personal
            selected.css_id == "RcpBrowserElementRecent"
          when :friends
            selected.css_id == "RcpBrowserElementRecent"
          when :public
            selected.css_id == "RcpBrowserElementAllRecipes"
        end
  end


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
    case selected.class.to_s
    when /CompositeUser/
      if tags.empty?
        # name = selected.content_name
        report = selected.content_empty_report
        sug = nil
      else
        report = "It looks like there isn't anything that matches your search in '#{selected.handle}'."
      end
    when /Composite/
      if selected.children.empty?
        verb = selected.content_name == "Friends" ? "picked" : "subscribed to"
        report = "There's no content here because you haven't #{verb} any #{selected.content_name}."
        sug = " getting one by selecting 'Make a Friend...' from the 'Friends' tab"
      elsif tags.empty?
        # name = selected.content_name
        report = selected.content_empty_report
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

# Element for a recipe list due to a tag
class RcpBrowserElementTaglist < RcpBrowserElement

  def initialize(level, args)
    super
    @persisters << :tagid unless @persisters.include? :tagid
    @level = level
    @persisters.each { |name| instance_variable_set("@#{name}", args[name]) if args[name] } if @persisters
    # @handle = "Tag #{@tagid.to_s}" # tag.name
    @classed_as = :personal
    tag # Will throw exception if tag doesn't exist
  end

  def css_id
    self.class.to_s+@tagid.to_s
  end

  def tag
    @tag ||= Tag.find(@tagid)
  end

  def find_by_content tag
    self if tag.id == @tagid
  end

  def handle extended=false
    extended ? "My <strong>#{tag.name}</strong> Collection".html_safe : tag.name
  end

  # Class method to return a hash sufficient to reconstruct the element
  def save
    result = Hash[@persisters.map { |name| instance_variable_get("@#{name.to_s}") && [name, instance_variable_get("@#{name.to_s}")] }.compact]
    result[:classname] = self.class.name
    result
  end

  private
  # The candidates are a list of recipes by id
  def candidates
    @candidates ||= tag.recipe_ids(@userid)
  end

end

# Element for a content List. A List is uniquely identified by 1) its title tag, and 2) the user
class RcpBrowserElementList < RcpBrowserElement

  def initialize(level, args)
    super
    @persisters << :tagid unless @persisters.include? :tagid
    @level = level
    @persisters.each { |name| instance_variable_set("@#{name}", args[name]) if args[name] } if @persisters
    # @handle = "Tag #{@tagid.to_s}" # tag.name
    @classed_as = :personal
    tag # Will throw exception if tag doesn't exist
  end

  def css_id
    self.class.to_s+@tagid.to_s
  end

  def add_path
    "/lists/new?modal=true"
  end

  def tag
    @tag ||= Tag.find(@tagid)
  end

  def list
    @list ||= List.assert(tag.name, user, create: true)
  end

  def find_by_content tag
    self if tag.id == @tagid
  end

  def handle extended=false
    extended ? "My <strong>#{tag.name}</strong> List".html_safe : tag.name
  end

  # Return a hash sufficient to reconstruct the element
  def save
    result = Hash[@persisters.map { |name| instance_variable_get("@#{name.to_s}") && [name, instance_variable_get("@#{name.to_s}")] }.compact]
    result[:classname] = self.class.name
    result
  end

  private
  # The candidates are a list of recipes by id
  def candidates
    @candidates ||= list.recipe_ids
  end

end
=end
