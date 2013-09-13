require 'open-uri'
require 'json'
require './lib/Domain.rb'

module RecipesHelper
  
# Sort out a suitable URL to stuff into an image thumbnail for a recipe
def recipe_image_div(recipe, div_class="recipe_image_div")
  begin
    return unless url = recipe.picdata
    options = { alt: "Image Not Accessible", id: "RecipeImage"+recipe.id.to_s }
    options[:class] = "stuffypic" unless url =~ /^data:/
    content = image_tag(url, options)
  rescue Exception => e
    if url
      url = "data URL" if url =~ /^data:/
    else
      url = "nil URL"
    end
    content = 
      "Error rendering image #{url.truncate(255)} from "+ (recipe ? "recipe #{recipe.id}: '#{recipe.title}'" : "null recipe")
    ExceptionNotifier::Notifier.exception_notification(request.env, e, data: { message: content}).deliver
  end
  content_tag( :div, content, class: div_class )
end
  
def grab_recipe_link label, recipe
end

def edit_recipe_link( label, recipe, options={})
    rcp_params = {
      rcpID: recipe.id,
      rcpTitle: recipe.title,
      rcpTagData: recipe.tag_data, # recipe.tags.map(&:attributes).to_json,
      rcpPicURL: recipe.picurl,
      rcpPrivate: recipe.private ? %q{checked="checked"} : "",
      rcpComment: recipe.comment,
      rcpStatus: recipe.status,
      authToken: form_authenticity_token
    }
    options[:class] = "edit_recipe_link "+(options[:class] || "")
    link_to label, "#", options.merge(remote: true, data: rcp_params)
end

# If the recipe doesn't belong to the current user's collection,
#   provide a link to add it
def ownership_status(rcp)
	# Summarize ownership as a list of owners, each linked to their collection
	(rcp.users.map { |u| link_to u.handle, collection_path( :owner=>u.id.to_s) }.join(', ') || "").html_safe
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
    out = (recipe.comment user_id) || ""
    out = "My two cents: '#{out}'<br>" unless out.empty?
=begin
    # Removed this to cut down on queries
    recipe.users.each { |user| 
        if (user.id != user_id) && (cmt=recipe.comment(user.id))
            out << "#{user.handle} sez: '#{cmt}'<br>"  unless cmt.blank?
        end
    }
=end
    out.html_safe
end

  # Provide the cookmark-count line
  def cookmark_count(rcp)
     count = rcp.num_cookmarks
     result = count.to_s+" Cookmark"+((count>1)?"s":"")
     if rcp.cookmarked session[:user_id]
        result << " (including mine)"
     else
        result << ": " + 
		  link_to("Update with Javascript Helper",
		  		 :url => {:action => "cmcount"},
				 :update => "response5")
     end
     "<span class=\"cmcount\" id=\"cmcount#{rcp.id}\">#{result}</span>".html_safe
  end

  # Declare a div for triggering a recipe edit operation
  def recipe_edit_trigger
    if capture_data = deferred_capture(false)
      debugger
=begin
      link_to_modal "", capture_recipes_url(capture_data), class: "trigger"
=end
      link_to( "", "", onclick: %Q{RP.dialog.get_and_go(event, '#{capture_recipes_url(capture_data)}', '')},
        class: "trigger")
    end
  end

=begin
  # Declare a div for triggering a recipe capture operation
  def recipe_collect_trigger
    if collect_data = deferred_collect(false)
      content_tag :a, "",
        href: collect_recipe_url(collect_data),
        class: "trigger"
    end
  end
=end

  def recipe_field_or_placeholder recipe, fieldname
    if recipe
      case fieldname
      when "authToken"
        form_authenticity_token
      when "rcpPrivate"
        recipe.private ? %q{checked="checked"} : ""
      else
        attrname = fieldname.sub("rcp", '').downcase
        recipe.send(attrname.to_sym).to_s.html_safe
      end
    else # Without a recipe specified, we simply return a placeholder for later
      "%%#{fieldname}%%" 
    end
  end
  
end
