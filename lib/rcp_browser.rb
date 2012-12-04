# Class for a single selectable collection of recipes, whether physical or virtual
require 'my_constants.rb'

class RcpBrowserElement
  attr_accessor :npages, :cur_page
  attr_reader :handle, :level
  @@nextid = 1  
  # Persisters for all browser-element nodes; these may be augmented by a subclass by
  # setting @persisters BEFORE handing off init to superclass
  @@persisters = [:selected, :handle, :nodeid, :userid]
  
  # Initialize a new element, either from supplied arguments or defaults
  def initialize(level, args)
    @persisters = [] unless @persisters
    @persisters = (@@persisters + @persisters).uniq
    @level = level
    @persisters.each { |name| instance_variable_set("@#{name}", args[name]) if args[name] } if @persisters
    @selected = false unless @selected
    @handle = "Mystery Element" unless @handle
    unless @nodeid = args[:nodeid]
      @nodeid = @@nextid
      @@nextid = @@nextid + 1
    end
  end
  
  # Class method to return a hash sufficient to reconstruct the element
  def save
    result = Hash[@persisters.map { |name| instance_variable_get("@#{name.to_s}") && [name, instance_variable_get("@#{name.to_s}")] }.compact]
    result[:classname] = self.class.name
    result
  end
  
  def css_class
    "RcpBrowserLevel"+@level.to_s+(@selected ? " selected" : "")
  end
  
  # ID for uniquely selecting the element
  def css_id
    "RcpBrowserElement"+@nodeid.to_s
  end
  
  # Return a list of recipes due to the element, constrained by the query
  def results(rcpquery)
    []
  end
  
  # HTML for interpolating into the display
  def html
    %Q{<div class="#{css_class}" id="#{css_id}">#{'&nbsp'*@level}#{handle}</div>}.html_safe
  end
  
  def select
    @selected = true
  end
  
  def deselect
    @selected = false
  end
  
end

# Class of composites, collections of browser elements
class RcpBrowserComposite < RcpBrowserElement
  attr_accessor :children
  
  def results(rcpquery)
    out = []
    @children.each do |child|
      out = out + child.results(rcpquery)
    end
  end
    
  # The HTML for the composite is just the HTML for the elements, joined with newlines
  def html
    list = [super] + @children.map { |child| child.html }
    list.join("\n")
  end
  
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
        RcpBrowserElementRecent.new(1, userarg),
        RcpBrowserElementNews.new(1, userarg),
        RcpBrowserElementAllRecipes.new(1, userarg)
        ] 
      @children[0].select
    end
  end
  
  # Accept new tags text, bust the cache, and return the new set of tags
  def tagstxt=(txt)
      # We either use the current tagstxt or the parameter, updating the tagstxt as needed
      @tagstxt = txt
      @tags = nil
      self.tags
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
              unless tag = Tag.strmatch( name, { matchall: true, uid: self.user_id }).first
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
    @children.map { |child| child.html }.join("\n").html_safe
  end
  
end

# Element for all the recipes for a user
class RcpBrowserElementUser < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = User.find(userid).name
  end
  
  def results(rcpquery)
    []
  end
end

# Element for all the recipes for the owner, with subheads for status and favored keys
class RcpBrowserCompositeUser < RcpBrowserComposite
  
  def initialize(level, args)
    super
    @handle = "My Recipes"
    @children =
    [ MyConstants::Rcpstatus_rotation, 
      MyConstants::Rcpstatus_favorites, 
      MyConstants::Rcpstatus_interesting, 
      MyConstants::Rcpstatus_misc].map do |status| 
      args[:status] = status
      RcpBrowserElementStatus.new(level+1, args)
    end if @children.empty?
  end
  
  def results(rcpquery)
    []
  end
end

# Composite for all the recipes for the user's friends, with subheads for each friend
class RcpBrowserCompositeFriends < RcpBrowserComposite
  
  def initialize(level, args)
    super
    @handle = "Friends' Collections"
  end
  
  def results(rcpquery)
    []
  end
end

# Element for all the recipes in a user's channels, with subheads for each channel
class RcpBrowserCompositeChannels < RcpBrowserComposite
  
  def initialize(level, args)
    super
    @handle = "Channels"
  end
  
  def results(rcpquery)
    []
  end
end

# Element for recent recipes 
class RcpBrowserElementRecent < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "Recent"
  end
  
  def results(rcpquery)
    []
  end
end

# Element for a news feed for a particular user
class RcpBrowserElementNews < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "News Feed"
  end
  
  def results(rcpquery)
    []
  end
end

# Element for a recipe list due to the status of a recipe
class RcpBrowserElementStatus < RcpBrowserElement
  
  def initialize(level, args)
    @persisters = (@persisters || []) << :status
    super
    @handle = "Status #{@status.to_s}"
  end
  
  def results(rcpquery)
    []
  end
end

# Element for a recipe list due to a tag
class RcpBrowserElementTaglist < RcpBrowserElement
  
  def initialize(level, args)
    super
    @tagid = args[:tagid]
    @handle = "Tag #{@tagid.to_s}"
  end
  
  def results(rcpquery)
    []
  end
end

# Element for a recipe list for all the recipes in the system
class RcpBrowserElementAllRecipes < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "RecipePower&nbspCollection"
  end

  def results(rcpquery)
    []
  end
  
end