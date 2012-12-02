# Class for a single selectable collection of recipes, whether physical or virtual
class RcpBrowserElement
  attr_accessor :npages, :cur_page
  attr_reader :handle, :level
  @@nextid = 1  
  @@persisters = [:selected, :handle, :nodeid, :userid]
  
  # Initialize a new element, either from supplied arguments or defaults
  def initialize(level, args)
    @level = level
    @@persisters.each { |name| instance_variable_set "@#{name}", args[name] } if @@persisters
    @selected = false unless @selected
    @handle = "Mystery Element" unless @handle
    unless @nodeid = args[:nodeid]
      @nodeid = @@nextid
      @@nextid = @@nextid + 1
    end
  end
  
  # Class method to return a hash sufficient to reconstruct the element
  def save
    result = Hash[@@persisters.map { |name| [name, instance_variable_get("@#{name.to_s}")] }]
    result[:classname] = self.class.name
    result
  end
  
  def css_class
    "RcpBrowserLevel"+@level.to_s+(@selected ? "Selected" : "")
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
    %Q{#{'\t'*@level}<div class="#{css_class}" id="#{css_id}">#{handle}</div>}.html_safe
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
    (super + @children.map { |child| child.html }).join("\n")
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

# Top-level recipe browser, comprising the standard lists
class RcpBrowser < RcpBrowserComposite
  
  def initialize(userid_or_argshash)
    args = (userid_or_argshash.class.name == "Fixnum") ? { userid: userid_or_argshash } : userid_or_argshash
    super(0, args)
    @handle = ""
    if @children.empty?
      userarg = { userid: args[:userid] }
      @children = [
        RcpBrowserElementUser.new(1, userarg),
        RcpBrowserElementFriends.new(1, userarg),
        RcpBrowserElementChannels.new(1, userarg),
        RcpBrowserElementRecent.new(1, userarg),
        RcpBrowserElementNews.new(1, userarg),
        RcpBrowserElementAllRecipes.new(1, userarg)
        ] 
    end
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
    @children.map { |child| child.html }.join("\n")
  end
  
end

# Element for all the recipes for a user
class RcpBrowserElementUser < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "My Recipes"
  end
  
  def results(rcpquery)
    []
  end
end

# Element for all the recipes for a user
class RcpBrowserElementFriends < RcpBrowserElement
  
  def initialize(level, args)
    super
    @handle = "Friends' Collections"
  end
  
  def results(rcpquery)
    []
  end
end

# Element for all the recipes in a user's channels
class RcpBrowserElementChannels < RcpBrowserElement
  
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
    super
    @handle = "Status #{status.to_s}"
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
    @handle = "All the Recipes In The WHole Wide World (of RecipePower)"
  end

  def results(rcpquery)
    []
  end
  
end