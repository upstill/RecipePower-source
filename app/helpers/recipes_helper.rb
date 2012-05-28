require 'open-uri'
require './lib/Domain.rb'

module RecipesHelper

def rcp_fitPic(rcp)
    # "fitPic" class gets fit inside pic_box with Javascript and jQuery
	if rcp.picurl
        "<img src=\"#{rcp.picurl}\" class=\"fitPic\" >".html_safe
	else
	    "Pic goes Here.".html_safe
	end
end

  # Declare the list of thumbnails for picking a page's image
  def rcp_choosePic rcp
      str = 
%Q{
    <div class="imagepicker">                                   
      <label for="recipe_picurl" id="recipe_pic_label">Picture of Recipe</label>
      <div class="preview">                                     
        <img src="#{rcp.picurl}" alt="Placeholder", class="fitPic">  
      </div>                                                    
      <br><button class="title">Pick Image</button>         
      <div class="content">                                     
        <div class="wrapper">                                   
          <ul>}+
          rcp.piclist.collect { |url|
    		"<li class=\"pickerImage\"><img src=\"#{url}\" alt=\"#{url}\"/></li>\n"
    	  }.join('')+
%q{       </ul>                                             
        </div>                                                  
      </div>                                                    
    </div>}
    str.html_safe
  end

# If the recipe doesn't belong to the current user's collection,
#   provide a link to add it
def ownership_status(rcp)
	# Summarize ownership as a list of owners, each linked to their collection
	(rcp.users.map { |u| link_to u.username, rcpqueries_path( :owner=>u.id.to_s) }.join(', ') || "").html_safe
end

def summarize_techniques(courses)
	englishize_list courses.collect{|e| "<strong>#{e.name}</strong>" }.join(', ')
end

def summarize_othertags(tags)
	tags.collect{|e| "<strong>#{e.name}</strong>" }.join(', ')
end

def summarize_ratings(ratings)
	englishize_list(ratings.collect { |r| "<strong>#{r.value_as_text}</strong>" }.join ', ')
end

def summarize_mainings(ings)
	englishize_list ings.collect{|e| "<strong>#{e.name}</strong>" }.join(', ')
end

def summarize_genres(genres)
	genres.collect{|e| "<strong>#{e.name}</strong>" }.join '/' 
end

def summarize_courses(courses)
	courses.length > 0 ? courses.collect{|e| "<strong>#{e.name}</strong>" }.join('/') : "dish"
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
    strjoin tags.collect{ |tag| link_to (enquote ? "'#{tag.name}'" : tag.name), tag }, before, after, joiner
end

def summarize_alltags(rcp)

    genrestr = tagjoin rcp.tags.where(tagtype: 1), false, "", " "
    rolestr = tagjoin rcp.tags.where(tagtype: 2), false, " for "

    procstr = tagjoin rcp.tags.where(tagtype: 3), false, " using ", " process"
    foodstr = tagjoin rcp.tags.where(tagtype: 4), false, " that includes "
    sourcestr = tagjoin rcp.tags.where(tagtype: 6), false, " from "
    authorstr = tagjoin rcp.tags.where(tagtype: 7), false, " by "
    toolstr = tagjoin rcp.tags.where(tagtype: 12), false, " with "

    occasionstr = tagjoin rcp.tags.where(tagtype: 8), false, " good for"
    intereststr = tagjoin rcp.tags.where(tagtype: 11), true, " tagged by Interest for "

    otherstr = tagjoin rcp.tags.where(tagtype: [0, 13, 14]), true, " Other tags: ", "."
    
    strlist = [sourcestr, authorstr, foodstr, procstr, toolstr].keep_if{ |str| !str.empty? }

    ("A "+genrestr+" recipe"+(strlist.shift || "")+
    strjoin(strlist, "", "", "; ")+"."+
    strjoin([occasionstr, intereststr], " ", ".", ",").capitalize+
    otherstr).html_safe
=begin
    "A [<genre> ]recipe[ for <role>][, from <source>][, by <author>][, made with <food>][, using <procstr> technique(s)][, with <tool>]
    [Good for <occasion>][, tagged for Interest(s) <interest>. Other tags: <Nutrient><Culinary Term><free tag>]"
  	othertags = rcp.tags.select { |t| t.tagtype.nil? || t.tagtype==0 }
  	genres = rcp.tags.select { |t| t.tagtype==1 }
  	courses = rcp.tags.select { |t| t.tagtype==2 }
  	techniques = rcp.tags.select { |t| t.tagtype==3 }
  	mainings = rcp.tags.select { |t| t.tagtype==4 }
  	summ = "...a"
	summ += " #{summarize_genres(genres)}" if genres.length>0
	summ += " #{summarize_courses(courses)}"
	summ += "," unless (summ.match 'dish$')
	summ += " rated #{summarize_ratings(rcp.ratings)}" if rcp.ratings.length>0
	summ += "," unless (summ.match 'dish$')
	summ += " made" if (mainings.length>0) || (techniques.length > 0)
	summ += " by #{summarize_techniques(techniques)}," if techniques.length>0
	summ += " using #{summarize_mainings mainings}," if mainings.length > 0
	summ += " that has been otherwise tagged \'#{summarize_othertags othertags}\'" if othertags.length > 0
	summ.length>9 ? (summ+".").html_safe : nil
=end
end

# Present the comments to this user. Now, all comments starting with his/hers, but ultimately those of his friends
def present_comments (recipe, user_id)
    out = (recipe.comment_of_user user_id) || ""
    out = "My two cents: '#{out}'<br>" unless out.empty?
    recipe.users.each { |user| 
        if (user.id != user_id) && (cmt=recipe.comment_of_user(user.id))
            out << "#{user.username} sez: '#{cmt}'<br>"  unless cmt.blank?
        end
    }
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
