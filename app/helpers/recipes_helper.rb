require 'open-uri'
require './lib/Domain.rb'

module RecipesHelper

# Declare a recipe's image in an adjustable box. The images are downloaded by
# the browser under Javascript and their dimensions adjusted.
def rcp_fitPic(rcp)
    # "fitPic" class gets fit inside pic_box with Javascript and jQuery
    id = "rcpPic"+rcp.id.to_s
	if rcp.picurl.blank?
	    %Q{<div class="centerfloat" id="#{id}">No Image Available</div>}.html_safe
	else
        %Q{<img src="#{rcp.picurl}" class="fitPic" id="#{id}" onload="fitImage(#{id});">}.html_safe
	end
end

  # Declare the list of thumbnails for picking a recipe's image.
  # It's sourced from the page by hoovering up all the <img tags that have
  # an appropriate file type.
  def rcp_choosePic rcp
      piclist = rcp.piclist.collect { |url|
  		"<li class=\"pickerImage\"><img src=\"#{url}\" alt=\"#{url}\"/></li>\n"
  	  }
  	if piclist.count > 0
        %Q{
            <div class="imagepicker">                                   
              <div class="preview">                                     
                <img src="#{rcp.picurl}" alt="No Image Available", class="fitPic">  
              </div>                                                    
              <br><button class="title">Pick Image</button>
              <div class="content">                                     
                <div class="wrapper">                                   
                  <ul>#{piclist.join('')}</ul>                                             
                </div>                                                  
              </div>                                                    
            </div>}.html_safe
    else
            %q{<div class="imagepicker">
                <label for="recipe_picurl" id="recipe_pic_label">No Picture Available</label>
            </div>}.html_safe                                   
    end
  end

# If the recipe doesn't belong to the current user's collection,
#   provide a link to add it
def ownership_status(rcp)
	# Summarize ownership as a list of owners, each linked to their collection
	(rcp.users.map { |u| link_to u.username, rcpqueries_path( :owner=>u.id.to_s) }.join(', ') || "").html_safe
end

# Return an enumeration of a series of strings, separated by ',' except for the last two separated by 'and'
# RETURN BLANK STRING IF STRS ARE EMPTY
def strjoin strs, before = "", after = "", joiner = ', '
    if strs.keep_if { |str| !str.blank? }.size > 0
        last = strs.pop
        liststr = strs.join joiner
        liststr += " and " unless liststr.blank?
        before+liststr+last+after
    else
        ""
    end
end

def tagjoin tags, enquote = false, before = "", after = "", joiner = ','
    strjoin tags.collect{ |tag| link_to (enquote ? "'#{tag.name}'" : tag.name), tag, class: "rcp_list_element_tag" }, before, after, joiner
end

# Provide an English-language summary of the tags for a recipe.
def summarize_alltags(rcp)

    tags = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]
    rcp.tags.each { |tag| tags[tag.tagtype] << tag }
    
    genrestr = tagjoin tags[1], false, "", " "
    rolestr = tagjoin tags[2], false, " for "

    procstr = tagjoin tags[3], false, " with ", " process"
    foodstr = tagjoin tags[4], false, " that includes "
    sourcestr = tagjoin tags[6], false, " from "
    authorstr = tagjoin tags[7], false, " by "
    toolstr = tagjoin tags[12], false, " with "

    occasionstr = tagjoin tags[8], false, " good for"
    intereststr = tagjoin tags[11], true, " tagged by Interest for "

    otherstr = tagjoin (tags[0]+tags[13]+tags[14]), true, " Miscellaneous tags: ", "."
    
    strlist = [sourcestr, authorstr, foodstr, procstr, toolstr].keep_if{ |str| !str.empty? }
    
    genrestr = "<span>untagged</span>" if strlist.empty? && genrestr.blank? && occasionstr.blank? && intereststr.blank? && otherstr.blank?
    if genrestr.blank?
        article = "A"
    else
        article = (genrestr =~ />[aeiouAEIOU]/i) ? "An " : "A "
    end
    
    ((article+genrestr+" recipe"+(strlist.shift || "")+
      strjoin(strlist, "", "", "; ")+".").sub(/A\s*recipe\./,'')+
    strjoin([occasionstr, intereststr], " ", ".", ",").capitalize+
    otherstr).html_safe
end

# Present the comments to this user. Now, all comments starting with his/hers, but ultimately those of his friends
def present_comments (recipe, user_id)
    out = (recipe.comment_of_user user_id) || ""
    out = "My two cents: '#{out}'<br>" unless out.empty?
=begin
    # Removed this to cut down on queries
    recipe.users.each { |user| 
        if (user.id != user_id) && (cmt=recipe.comment_of_user(user.id))
            out << "#{user.username} sez: '#{cmt}'<br>"  unless cmt.blank?
        end
    }
=end
    out.html_safe
end

# Provide the cookmark-count line
def cookmark_count(rcp)
     count = rcp.num_cookmarks
     result = count.to_s+" Cookmark"
     result << "s" if count>1
     if rcp.marked? session[:user_id]
        result << " (including mine)"
     else
        result << ": " + 
		  link_to("Update with Javascript Helper",
		  		 :url => {:action => "cmcount"},
				 :update => "response5")
     end
     "<span class=\"cmcount\" id=\"cmcount#{rcp.id}\">#{result}</span>".html_safe
end

end
