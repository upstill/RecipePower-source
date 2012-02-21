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

  def summarize_alltags(rcp)
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
  end

   def add_genre_link(name)
	link_to_function name do |page|
     	   page.insert_html :bottom, :genres, :partial => 'genre', :object=>Genre.new
      end
   end

   def show_field(label, content)
       "<p><strong>#{label}: </strong> #{content} </p>".html_safe unless content.empty?
   end

  def tiny_logo
    logo = image_tag("RPlogo.png", :alt=>"RecipePower", :class=>"tiny_logo")
    link_to logo, root_path
  end

  # Make a recipe's url nice for display
=begin
  def display_url(rcp)
      if(url = rcp.url)
         mappings = {"nytimes.com"=>"The New York Times", 
      	   "smittenkitchen.com"=>"Smitten Kitchen"}
         domain = domain_from_url(url)
         mappings[domain] || domain
      else
         ""
      end
  end
=end

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
