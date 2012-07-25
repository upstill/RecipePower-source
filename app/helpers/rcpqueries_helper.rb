module RcpqueriesHelper

   # Build a link for getting back to the current user's list
   def backtome
	if @rcpquery.owner_id != @rcpquery.user_id 
	    s = <<BLOCK_END
	        <a href="rcpqueries?owner=#{@rcpquery.user_id}" id="rcpquery_owner_return">
		   (back to #{(@rcpquery.user_id==User.guest_id) ? "the Big List" : "my collection"})
		</a>
BLOCK_END
	    s.html_safe
	end
   end
   
   def explain_empty (rq)
       explan = rq.tags.empty? ? 
                "Sorry, this collection is empty. Try picking another collection above, or go out to the Web and bring something back!" :
                "Sorry, this list doesn't have any recipes that match what you're looking for. Try searching on fewer tags, 
			    or pick another list. <br>Or go out to the Web and bring something back!"
%Q{	    <br>
		#{image_tag "sad-icon.png", :alt=>"RecipePower", :id=>"sad_img"}
		<p class="airy">#{explan}</p>}.html_safe
   end
   
   def query_listid
       "rcpquery_"+@rcpquery.which_list+"_list"
   end
   
  def query_container kind, msg
    %Q{<div class="rcplist_container" id="rcpquery_#{kind}_list_container">#{msg}</div>}.html_safe
  end

     def query_tabset
       s = <<BLOCK_END
  	<div id="rcpquery_tabset" value="#{@rcpquery.status_tab}"> 
  	    <ul>
  		<li><a href="rcpqueries/tablist?status=1" title="Show recipes that are in your active rotation">Rotation</a></li> 
  		<li><a href="rcpqueries/tablist?status=2" title="Show favorite recipes">Favorites</a></li> 
  		<li><a href="rcpqueries/tablist?status=4" title="Show recipes that you've earmarked as 'interesting''">Interesting</a></li>
  		<li><a href="rcpqueries/tablist?status=8" title="Show all your cookmarks">All Cookmarks</a></li>
  		<li><a href="rcpqueries/tablist?status=16" title="Show recent cookmarks">Recent</a></li>
  	    </ul> 
  	</div>
BLOCK_END
       s.html_safe
     end
=begin   
     def query_friendset f, channel=false
       what = channel ? "Channels" : "Friends"
       getmore = "(Get More #{what})"
       friends_list = @rcpquery.friend_selection_list channel
       id = "rcpquery_" + (channel ? "channels" : "friends") + "_list"
       h4 = %Q{<h4 class="rcpquery_list_header" id="#{id}_header">}
       result = h4 + case friends_list.length
       when 1
         str = channel ? "Cookmarks from your channels" : "Friends\' cookmarks"
         "#{str} go here. Why not #{link_to 'get some', users_profile_path}?</h4>"
       when 2
         str = channel ? 'from channel' : 'of friend'
         "Cookmarks #{str} '#{friends_list.last[0]}' #{link_to getmore, users_profile_path}</h4>"
       else
         %Q{Cookmarks from #{what} #{link_to getmore, users_profile_path}</h4>
           #{f.select (channel ? :channel_id : :friend_id), friends_list}}
       end
       result << %Q{<div class="rcpquery_list" id="#{id}"></div>} if(friends_list.length > 1)
       result.html_safe
     end
=end
     def query_friendstart f, channel=false
       what = channel ? "Channels" : "Friends"
       getmore = "(Get More #{what})"
       friends_list = @rcpquery.friend_selection_list channel
       id = "rcpquery_" + (channel ? "channels" : "friends") + "_list"
       h4 = %Q{<h4 class="rcpquery_list_header" id="#{id}_header">}
       result = h4 + case friends_list.length
       when 1
         str = channel ? "Cookmarks from your channels" : "Friends\' cookmarks"
         "#{str} go here. Why not #{link_to 'get some', users_profile_path}?</h4>"
       when 2
         str = channel ? 'from channel' : 'of friend'
         "Cookmarks #{str} '#{friends_list.last[0]}' #{link_to getmore, users_profile_path}</h4>"
       else
         %Q{Cookmarks from #{what} #{link_to getmore, users_profile_path}</h4>
           #{f.select (channel ? :channel_id : :friend_id), friends_list}}
       end
       # result << %Q{<div class="rcpquery_list" id="#{id}"></div>} if(friends_list.length > 1)
       result.html_safe
     end
   
   def pagination_link (text, pagenum)
        # "<span value='#{p.to_s}' class='pageclickr'>#{p.to_s}</span>"
        # We install the actual pagination handler in RPquery.js::queryTabOnLoad
        link_to_function text.html_safe, ";", class: "pageclickr", value: pagenum.to_s
   end
   
    def pagination_links
        per_page = @rcpquery.page_length
        npages = @rcpquery.npages 
        cur_page = @rcpquery.cur_page        
        maxlinks = 11
        halfwidth = (maxlinks-6)/2

        cur_page = npages if cur_page > npages
        blockleft = cur_page-1-halfwidth
        blockright = cur_page-1 + halfwidth
        shift = (3-blockleft)
        if(shift > 0)
            blockleft = blockleft + shift
            blockright = blockright + shift
        end
        shift = blockright - (npages-4)
        if(shift > 0)
            blockright = blockright - shift
            blockleft = blockleft - shift
            blockleft = 3 if(blockleft < 3)
        end

        blockleft = 0 unless blockleft > 3
        blockright = npages-1 unless blockright < (npages-4)
        pages = (blockleft..blockright).map { |i| i+1 }
        pages = [1,2,nil] + pages if(blockleft > 0)
        pages << [ nil, (npages-1), npages] if(blockright < (npages-1))
        links = pages.flatten.map do |p| 
            case p
            when nil
                "<span class=\"disabled\">...</span>"
            when cur_page
                "<span class=\"current\">#{p.to_s}</span>"
            else
                pagination_link p.to_s, p
            end
        end
        if cur_page > 1
            links.unshift pagination_link("&#8592; Previous", cur_page-1)
            links.unshift pagination_link("First ", 1)
        else
            links.unshift "<span class=\"disabled previous_page\">&#8592; Previous</span>"
            links.unshift "<span class=\"disabled previous_page\">First </span>"
        end
        if cur_page < npages
            links << pagination_link("Next &#8594;", cur_page+1)
            links << pagination_link(" Last", npages)
        else
            links << "<span class=\"disabled next_page\">Next &#8594;</span>"
            links << "<span class=\"disabled next_page\"> Last</span>"
        end
        links.join(' ').html_safe
    end
end
