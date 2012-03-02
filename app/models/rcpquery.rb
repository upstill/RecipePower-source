require "my_constants.rb"

class Candihash < Hash
    # Initialize the candihash to a set of keys
    def initialize(startset, mode)
       startset.each { |rid| self[rid.to_s] = 0 }
       @mode = mode
    end

    def reset keys
       self.clear
       keys.each { |key| self[key.to_s] = 0 }
    end

    # Apply a new set of keys to the existing set, either
    # by bumping the presence counts (:rcpquery_loose)
    # or by intersecting the sets (:rcpquery_strict)
    def apply(newset)
        case @mode 
	when :rcpquery_strict
	    newset.select { |id| self[id.to_s] }
	    self.reset newset
	when :rcpquery_loose 
	    newset.each { |id| self[id.to_s] += 1 if self[id.to_s] }
	end
    end

    # Return the keys as an integer array, sorted by number of hits
    # 'rankings' is an array of rid/ranking pairs, denoting the place of 
    # each recipe in some prior ordering. Use that ranking to constrain the output
    def results (rankings)
	
	# Extract the keys and sort them by success in matching
	if @mode == :rcpquery_loose
	    buffer1 = self.keys.select { |k| self[k] > 0 } # (In random order)
            buffer1.sort! { |k1, k2| self[k1] <=> self[k2] } 
	else
	    buffer1 = self.keys # Random order
	end

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
    attr_accessible :status, :tag_tokens, :tags, :ratings_attributes, :page_length, :cur_page,
    	:session_id, :user_id, :owner_id, :listmode_str, :querymode_str, :querytext # From database
    attr_reader :ratings
    attr_reader :tags
    attr_reader :tag_tokens
    attr_reader :listmode_str
    attr_reader :querymode_str
    attr_accessor :page_length, :cur_page

    after_initialize :my_init
    after_find :my_reinit
    
    def page_length()
        25
    end
    
    def page_length=(length)
    end
    
    def cur_page()
        @cur_page || 1
    end
    
    def cur_page=(p)
        @cur_page = p.to_i if p
    end
    
    def npages
        (results.count+(page_length-1))/page_length
    end
    
    # Return a list of results based on the paging parameters
    def results_paged
        first = (cur_page-1)*page_length
        last = first+page_length-1
        maxlast = results.count-1 
        last = maxlast if last > maxlast
        results[first..last]
    end

    # Selectors for setting the list's display mode
    @@listmodes = [["Just Text", :rcplist_text],
  		   ["Small Pics", :rcplist_smallpic],
  		   ["Big Pics", :rcplist_bigpic]]
    def self.listmode_select
       @@listmodes
    end

    def listmode_str=(str)
        @listmode = str.to_sym
	self.listmode = str
    end

    def listmode_str
        @listmode
    end

    # Selectors for setting the list's searching mode
    @@querymodes = [["Strict Searching", :rcpquery_strict],
  		    ["Loose Searching", :rcpquery_loose]]

    def self.querymode_select
        @@querymodes
    end

    def querymode_str=(str)
        @querymode = str.to_sym
	self.querymode = str
    end

    def querymode_str
        self.querymode
    end

    def selectionlist
    	User.selectionlist :owner_id=>self.owner_id, :user_id=>self.user_id
    end

    def my_init

    	self.tagstxt = ""  unless self.tagstxt
	self.tag_tokens = self.tagstxt

	self.ratingstxt = "" unless self.ratingstxt
	@ratings = self.ratingstxt.split(',').map do  |r| 
	    idval = r.split(':')
	    Rating.new :scale_id=>idval.first.to_i, :scale_val=>idval.last.to_i
	end

	self.fromsitestxt = "" unless self.fromsitestxt
	self.circlestxt = "" unless self.circlestxt
	self.querytext = "" unless self.querytext

	self.user_id = User.guest_id unless self.user_id
	self.owner_id = User.guest_id unless self.owner_id

	self.status = MyConstants::Rcpstatus_misc unless self.status

	self.listmode = :rcplist_smallpic.to_s unless self.listmode
	   # (vs. :rcplist_text or :rcplist_bigpic)  Default to small-pic listing
	@listmode = self.listmode.to_sym 

	self.querymode = :rcpquery_loose.to_s unless self.querymode # vs. :rcpquery_strict
	@querymode = self.querymode.to_sym

	@fromsites = [] # An array of site ids
	@circles = []   # An array of user ids of type 'circle'
	@rankings = {}	# For each ranked recipe, a recipe_id/ranking pair

	@results_pp = 10
	@results_offset = 0
    end

    def my_reinit
    	# When a query is (re)loaded from the database, convert holder fields
	tag_tokens = self.tagstxt
    end

    # updater for ratings attributes, i.e., translate betw params and ratings
    def ratings_attributes=(ra)
	rlist = []
	rlist = ra.values.map { |rv|
	    Rating.new( :scale_id => rv["scale_id"],
	    		:scale_val => rv["scale_val"] ) if rv["scale_val"] && (rv["_destroy"] != "1")
	}.compact
	self.ratings = rlist
    end

    # def status_txt=(str)
        # self.status = str.to_i
    # end

    # def status_txt(str)
        # self.status
    # end

    # Return the 0-based index of the tab representing the current status
    def status_tab
        {"1"=>0, "2"=>1, "4"=>2, "8"=>3, "16"=>4}[self.status.to_s]
    end

    def ratings=(rlist)
	self.ratingstxt = rlist.map { |r| r.scale_id.to_s+":"+r.scale_val.to_s }.join ','
    	@ratings = rlist
    end

    def ratings
        @ratings
    end

    # Get the results of the current query.
    def results
        # Try to match prior query for this user and fetch rankings array
	# "match" has fewest num. of differing elements

	# Get the initial working list from Rcpref model
	# Rcpref.recipe_ids can take:
	# :comment is text to match against the comment field
	# :status is the set of status flags to match 
	matchText = (self.querymode.to_sym == :rcpquery_strict && !self.querytext.empty?) ?
		self.querytext : nil
	candidates = Rcpref.recipe_ids( 
			self.owner_id, self.user_id,
			:status=>self.status,
			:title=>matchText,
			:comment=>matchText)

	# XXX Merge in the lists for each circle
	# @circles.each { |circle_id| candidates = candidates | Rcpref.recipe_ids(circle_id, self.user_id) }

	matchText = (self.querymode.to_sym == :rcpquery_loose && !self.querytext.empty?) ?
		self.querytext : nil
	if !ratings.empty? || !@tags.empty? || matchText # We purge/massage the list ONLY if there is a query here
	   # Convert candidate array to a hash recipe_id=>#hits

	   candihash = Candihash.new candidates, @querymode

	   # XXX Filter for sites

	   # Rank/purge for ratings
	   @ratings.each { |rating| candihash.apply rating.recipes }

	   # Rank/purge for tag matches
	   @tags.each { |tag| candihash.apply tag.recipe_ids }
	
	   # Rank/purge for text matches in comment
	   if matchText
	      # Get candidates that match in the comments field
	      candihash.apply Rcpref.recipe_ids(self.owner_id, self.user_id,
						:status=>self.status,
						:comment=>matchText) 
	      # Get candidates that match in the title
	      candihash.apply Rcpref.recipe_ids(self.owner_id, self.user_id,
						:status=>self.status,
						:title=>matchText) 
	   end
	   candidates = candihash.results(@rankings).reverse
	end
	
	# Derive the final ordering for the candidates based on prior rankings
	# and convert from rids back into recipes
	candidates.map { |rid| Recipe.find(rid) } 
    end

  # Virtual attribute tag_tokens accepts the tags for the query
  # ids is the parameter string for the tokens
  def tag_tokens=(paramstr)
	# Keep the saveable query up to date
	self.tagstxt = paramstr
	@tags = paramstr.split(",").map { |e| 
	  if(e=~/^\d*$/) # numbers (sans quotes) represent existing tags
	     Tag.find e.to_i
	  else
	     e.gsub!('\'','') # Strip out enclosing quotes
	     # Convert the tag to an id if poss.
    	     (thetags = Tag.where "name like ?", e) ? thetags[0] : Tag.new(:name=>e)
	  end
	}
  end

  def tag_tokens
     self.tagstxt
  end

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
            User.find(self.owner_id).username+"\'s Cookmarks"
        end
    end

    # Fetch and use parameters to revise a query record before returning
    def self.fetch_revision(id, uid, *params)
        result = self.find(id)
	result.session_id = uid
	result.update_attributes(params[0])
    	result.save
	result
    end
end
