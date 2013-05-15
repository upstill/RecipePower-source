module SeekerHelper
	def seeker_table(heading, column_heads )
	  header = heading ? "<h3>#{heading}</h3>" : ""
    pager = (@seeker.npages > 0) ?
	  %Q{
    	<tr><td colspan=6>
    		<div class="digg_pagination">
    			#{ pagination_links @seeker.npages, @seeker.cur_page, @seeker.query_path }
    		</div>
    	</td></tr>
    } : ""
	  (%Q{
      #{header}
  		<table class="table table-striped">
  		  <thead>
  		    <tr>
  		}+column_heads.compact.collect { |header| "<th>#{header}</th>" }.join("\n")+
  	  %Q{
  		    </tr>
  		  </thead>
  		  <tbody class="collection_list">
  				#{collection_results}
  				#{pager}
  		  </tbody>
  		</table>
  	}
  	).html_safe
  end
end
