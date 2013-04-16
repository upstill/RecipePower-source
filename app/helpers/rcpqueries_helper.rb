module RcpqueriesHelper

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
  		<li><a href="rcpqueries/tablist?status=1" title="Show recipes that you're actually cooking these days">Now Cooking</a></li> 
  		<li><a href="rcpqueries/tablist?status=2" title="Show favorite recipes"><% t :recipe_status_high %></a></li> 
  		<li><a href="rcpqueries/tablist?status=4" title="Show recipes that you've earmarked to try sometime">To Try</a></li>
  		<li><a href="rcpqueries/tablist?status=8" title="Show all the cookmarks you've collected">All My Cookmarks</a></li>
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
end
