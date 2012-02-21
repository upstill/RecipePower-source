module RcpqueriesHelper

   # Build a link for getting back to the current user's list
   def backtome
	if @rcpquery.owner_id != @rcpquery.user_id 
	    s = <<BLOCK_END
	        <a href="rcpqueries?owner=#{@rcpquery.user_id}" id="rcpquery_owner_return">
		   (back to #{(@rcpquery.user_id==User.guest_id) ? "the Big List" : "my list"})
		</a>
BLOCK_END
	    s.html_safe
	end
   end

   def query_tabset
     s = <<BLOCK_END
	<div id="rcpquery_tabset" value="#{@rcpquery.status_tab}"> 
	    <ul>
		<li><a href="rcpqueries/relist?status=1" title="rotation_tab">Rotation</a></li> 
		<li><a href="rcpqueries/relist?status=2" title="favorites_tab">Favorites</a></li> 
		<li><a href="rcpqueries/relist?status=4" title="interesting_tab">Interesting</a></li>
		<li><a href="rcpqueries/relist?status=8" title="all_tab">All Cookmarks</a></li>
		<li><a href="rcpqueries/relist?status=16" title="recent_tab">Recent</a></li>
	    </ul> 
	</div>
BLOCK_END
     s.html_safe
   end
end
