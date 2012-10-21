require "my_constants.rb"

# Class for a hash of recipe keys, for sorting as integers and applying search results
class Candihash < Hash
    # Initialize the candihash to a set of keys
    def initialize(startset) # , mode)
       startset.each { |rid| self[rid.to_s] = 0 }
       # @mode = mode
    end

    def reset keys
       self.clear
       keys.each { |key| self[key.to_s] = 0 }
    end

    # Apply a new set of keys to the existing set, either
    # by bumping the presence counts (:rcpquery_loose)
    # or by intersecting the sets (:rcpquery_strict)
    def apply(newset)
        # case @mode 
    	# when :rcpquery_strict
    	    # newset.select { |id| self[id.to_s] }
    	    # self.reset newset
    	# when :rcpquery_loose 
    	    newset.each { |id| self[id.to_s] += 1 if self[id.to_s] }
    	# end
    end

    # Return the keys as an integer array, sorted by number of hits
    # 'rankings' is an array of rid/ranking pairs, denoting the place of 
    # each recipe in some prior ordering. Use that ranking to constrain the output
    def results (rankings)
    	# Extract the keys and sort them by success in matching
    	buffer1 = self.keys.select { |k| self[k] > 0 }.sort! { |k1, k2| self[k1] <=> self[k2] } 

    	return buffer1 if rankings.blank?
    	# See if the prior rankings have anything to say about matters
    	buffer2 = rankings.keys.keep_if { |k| self[k] } # Only keep found keys
    	return buffer1.map { |k| k.to_i } if buffer2.empty?

    	# Apply rankings from prior queries
    	buffer2 = rankings.keys.sort { |k1, k2| self[k1] < 0 ? -1 : (self[k2] < 0 ? 1 : (self[k1] <=> self[k2])) }

    	# Now we have two buffers of key strings, ordered by desired output.
    	# We also have 'rankings', that states the desired slot for each key
    	# Keys in buffer2 go into their stated slot (or at the end)
    	result = []
    	# Process keys in order
    	until buffer1.empty? || buffer2.empty?
    	    if(rankings[buffer2.first] == result.size)
    	        result.push buffer2.shift
    	    else # Slot not occupied from rankings
    		id = buffer1.shift
    	        result.push id unless rankings[id] # ...but this id may have a later slot
    	    end
    	end
    	result << buffer1 unless buffer1.empty?
    	result << buffer2 unless buffer2.empty?
    	result.map { |r| r.to_i }
    end

end

class Rcpquery < ActiveRecord::Base
    serialize :specialtags, Hash
    
    attr_accessible :status, :session_id, :user_id, :owner_id, :tag_tokens, :tag_ids, :tags, :page_length, :cur_page, 
        :listmode_str, :owner_id, :friend_id, :channel_id, :which_list
    belongs_to :owner, :class_name => "User"
    belongs_to :friend, :class_name => "User"
    belongs_to :channel, :class_name => "User"
    attr_reader :tags
    attr_reader :tag_tokens
    attr_reader :results
    attr_accessor :page_length
    
    after_initialize :my_init
    after_find :my_reinit

    def my_reinit
	    tag_tokens = self.tagstxt
    end

    # Selectors for setting the list's display mode
    @@listmodes = [["Just Text", :rcplist_text],
  		   ["Small Pics", :rcplist_smallpic],
  		   ["Big Pics", :rcplist_bigpic]]
  	
  	# Provide a list of display-mode options suitable for a select menu	   
    def self.listmode_select
       @@listmodes
    end
    
  	# Provide a list of friends suitable for a select menu	   
    def friend_selection_list channel = false
        [[channel ? "All Channels" : "All Friends", 0]] + 
        (self.owner ? self.owner.follows(channel).map { |f| [f.handle, f.id]} : [])
    end
    
    def listmode_str=(str)
        @listmode = str.to_sym
	    self.listmode = str
    end

    def listmode_str
        @listmode
    end
=begin
    def selectionlist
    	User.selectionlist :owner_id=>self.owner_id, :user_id=>self.user_id
    end
=end
    
    def my_init

    	self.tagstxt = ""  unless self.tagstxt

    	self.user_id = User.guest_id unless self.user_id
    	self.owner_id = User.guest_id unless self.owner_id

    	self.status = MyConstants::Rcpstatus_misc unless self.status
    	self.specialtags = self.specialtags || {}

    	self.listmode = :rcplist_smallpic.to_s unless self.listmode
    	   # (vs. :rcplist_text or :rcplist_bigpic)  Default to small-pic listing
    	@listmode = self.listmode.to_sym 

    	# self.querymode = :rcpquery_loose.to_s unless self.querymode # vs. :rcpquery_strict
    	# @querymode = self.querymode.to_sym

    	@fromsites = [] # An array of site ids
    	@circles = []   # An array of user ids of type 'circle'
    	@rankings = {}	# For each ranked recipe, a recipe_id/ranking pair

    	@results_pp = 10
    	@results_offset = 0
    	@results = nil
    end

    # Return the 0-based index of the tab representing the current status
    def status_tab
        {"1"=>0, "2"=>1, "4"=>2, "8"=>3, "16"=>4}[self.status.to_s]
    end

protected
    # Get the results of the current query.
    def result_ids
    	return @results if @results # Keeping a cache of results
        # Try to match prior query for this user and fetch rankings array
        # "match" has fewest num. of differing elements
        candidates = nil
        sources = nil
        if user = User.where(id: self.owner_id).first
          if self.which_list =~ /mine/
            if (self.status == 16) # Recent list: pre-empt to use recently-touched list
              # The touches are collected in touch order 
              candidates = user.touches.map { |touch| touch.recipe_id }
            else
              sources = self.owner_id
            end
          elsif self.which_list =~ /friend/
            sources = (self.friend && self.friend.id) || user.follows(false).map { |followee| followee.id }
          elsif self.which_list =~ /channel/
            sources = (self.channel && self.channel.id) || user.follows(true).map { |followee| followee.id }
          end
        end
        # Now sources is either a user id, an array of ids, or nil (for the master list)

        # First, get a set of candidates, determined by:
        # -- who the owner of the list is 
        # -- who the viewer is
        # -- targetted status of the recipe (Rotation, etc.)
        # -- text to match against titles and comments
        candidates = candidates || Rcpref.recipe_ids( sources, self.user_id, status: self.status)
    	
        unless self.tags.empty?
            # We purge/massage the list ONLY if there is a tags query here
            # Otherwise, we simply sort the list by mod date
            # Convert candidate array to a hash recipe_id=>#hits
            candihash = Candihash.new candidates
            
            # Rank/purge for tag matches
            @tags.each { |tag| 
                candihash.apply tag.recipe_ids if tag.id > 0 # A normal tag => get its recipe ids and apply them to the results
                # Get candidates by matching the tag's name against recipe titles and comments
                candihash.apply Rcpref.recipe_ids(sources, self.user_id,
                                                :status=>self.status,
                                                :comment=>tag.name) 
                # Get candidates that match specialtags in the title
                candihash.apply Rcpref.recipe_ids(sources, self.user_id,
                                                :status=>self.status,
                                                :title=>tag.name) 
            }
            # Convert back to a list of candidate ids
            candidates = candihash.results(@rankings).reverse
    	end
        @results = candidates
    end
public
    # Virtual attribute tag_tokens accepts the tag string for the query and generates the 
    # current tag set, along with the necessary specialtags
    # paramstr is the parameter string for the tokens
    # NB: The rcpquery takes both tag ids and unaffiliated strings for full-text searching.
    # The latter are converted to special tags stored with the query, and given a negative
    # id.
    def tag_tokens=(paramstr)
        # We either use the current tagstxt or the parameter, updating the tagstxt as needed
        self.tagstxt = paramstr
        @tags = nil
        self.tags
    end
    
    def tag_ids=(ids)
        self.tagstxt = ids.collect { |id| id.to_s }.join ','
        @tags = nil
    end
    
    # We set the tags to an array of tags
    def tags=(tagset)
        @tags = tagset
        self.tagstxt = @tags.collect { |t| t.id.to_s }.join ','
    end
  
    # Get the current set of tags based on the current tagstxt, including special tags
    def tags
        return @tags if @tags # Use cache, if any
        newspecial = {}
        oldspecial = self.specialtags || {}
        # Accumulate resulting tags here:
        @tags = []
        self.tagstxt.split(",").each do |e| 
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
                    tag = Tag.new(name: name )
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
        self.tagstxt = @tags.collect { |t| t.id.to_s }.join ','
        self.specialtags = newspecial
        @tags
    end

  def tag_tokens
     self.tagstxt
  end
=begin
    # Generate a title for labelling the query results
    def title
        case self.owner_id
        when User.guest_id
            "Cookmarks in RecipePower"
        when User.super_id
            "All the Cookmarks in the Whole Wide World"
        when self.user_id
            "My Cookmarks"
        else
            User.find(self.owner_id).handle+"\'s Cookmarks"
        end
    end
=end
  # Fetch and use parameters to revise a query record before returning
  def self.fetch_revision(id, uid, params)
    # This is all very straightforward, EXCEPT that we allow the 'tag_tokens' query string
    # to include both tagids (for searching on tags) and plain text strings. The latter we 
    # turn into 'specialtags' for searching titles and comments; they appear in the tags array
    # as tags with negative ids
    result = Rcpquery.where(:id => id).first || Rcpquery.create(user_id: uid, owner_id: uid)
    result.session_id = uid
    if list = params[:list]
      list =~ /^(\D*)(\d*)$/
      result.which_list = $1
      # idspec of 0 denotes "all friends/channels"; 
      # absent idspec denotes "current friend/channel"
      # idspec as value denotes specific friend/channel
      if user = User.where(id: $2).first
          case result.which_list
          when "friends"
            result.friend = user
          when "channels"
            result.channel = user
          end
      end
     # else
        # result.which_list = "mine"
    end
    result.update_attributes(params)
    result.save
    result
  end

    # ------------------ Methods in support of paging results ---------------
    
    # Current # of results per page
    def page_length()
        10
    end

    def page_length=(length)
    end
=begin
    # Page we're now on
    def cur_page()
        @cur_page || 1
    end

    def cur_page=(p)
        @cur_page = p.to_i if p
    end
=end

    # How many pages in the current result set?
    def npages
        (self.result_ids.count+(page_length-1))/page_length
    end
    
    # Are there any recipes waiting to come out of the query?
    def empty?
        self.result_ids.empty?
    end

    # Return a list of results based on the paging parameters
    def results_paged
        # No paging for 0 or 1 page
        npg = self.npages
        results = self.result_ids
        maxlast = results.count-1 
        if npg <= 1
            first = 0
            last = maxlast
        else
            # Clamp current page to last page
            cpg = self.cur_page || 1
            cpg = self.cur_page = npg if cpg > npg
        
            # Now get indices of first and last records on the page
            first = (cpg-1)*page_length
            last = first+page_length-1
            last = maxlast if last > maxlast
        end
        results[first..last].collect { |rid| Recipe.where( id: rid ).first }.compact
    end
end
