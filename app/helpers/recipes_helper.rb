require 'open-uri'
require 'json'
require './lib/Domain.rb'

module RecipesHelper
  
def grab_recipe_link label, recipe
end

def edit_recipe_link( label, recipe, *options)
  if params[:controller] != 'rcpqueries'
    rcp_params = {
      rcpID: recipe.id,
      rcpTitle: recipe.title,
      rcpTagData: recipe.tags.map(&:attributes).to_json,
      rcpPicURL: recipe.picurl,
      rcpPrivate: recipe.private ? %q{checked="checked"} : "",
      rcpComment: recipe.comment,
      rcpStatus: recipe.status,
      authToken: form_authenticity_token
    }
    link_to_function label, "RP.edit_recipe.go(#{rcp_params.to_json});", *options
  else
    link_to_function label, "recipePowerGetAndRunJSON( '#{edit_recipe_path(recipe)}', 'modeless', 'at_left');"
  end
end

# Show a thumbnail of a recipe's image, possibly with a link to an editing dialog
def recipe_pic_field(rcp, form, editable = true)
  picurl = @recipe.picurl
  preview = content_tag(
    :div, 
    recipe_fit_pic(@recipe, "PickPicture.png", "div.recipe_pic_preview img")+
              form.text_field(:picurl, rel: "jpg,png,gif", hidden: true),
    class: "recipe_pic_preview"
  )
  picker = editable ?
    content_tag(:div,
          link_to( "Pick Picture", "/", :data=>"recipe_picurl;div.recipe_pic_preview img", :class => "pic_picker_golink")+
          pic_picker_shell(), # pic_picker(@recipe.picurl, @recipe.url, @recipe.id), 
          :class=>"recipe_pic_picker"
          ) # Declare the picture-picking dialog
  : ""
  content_tag :div, preview + picker, class: "edit_recipe_field pic"
end

# If the recipe doesn't belong to the current user's collection,
#   provide a link to add it
def ownership_status(rcp)
	# Summarize ownership as a list of owners, each linked to their collection
	(rcp.users.map { |u| link_to u.handle, rcpqueries_path( :owner=>u.id.to_s) }.join(', ') || "").html_safe
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

# This is hardwired HTML for the recipe editing dialog, suitable for embedding into the dialog.
# In fact, that's just what happens in edit_recipe.go
def recipe_editor
  editor = { :string =>
      %q{
		<form accept-charset="UTF-8" action="/recipes/%%rcpID%%" class="edit_recipe" data-remote="true" data-type="json" id="edit_recipe_%%rcpID%%" method="post"><div style="margin:0;padding:0;display:inline"><input name="utf8" type="hidden" value="&#x2713;" /><input name="_method" type="hidden" value="put" /><input name="authenticity_token" type="hidden" value="%%authToken%%" /></div>
      <div class="edit_recipe_field pic"><div class="recipe_pic_preview"><img alt="Some Image Available" class="fitPic" id="rcpPic%%rcpID%%" onload="fitImageOnLoad('div.recipe_pic_preview img')" src="%%rcpPicURL%%" /><input hidden="hidden" id="recipe_picurl" name="recipe[picurl]" rel="jpg,png,gif" size="30" type="text" value="%%rcpPicURL%%" /></div>
        <div class="recipe_pic_picker">
         <a href="/" class="pic_picker_golink" data="recipe_picurl;div.recipe_pic_preview img">Pick Picture</a>
         <div class="pic_picker" data-url="/recipes/%%rcpID%%/edit?pic_picker=true" style="display:none;"></div>
        </div>
      </div>
         <div class="edit_recipe_field tags" >
       		<label for="recipe_tag_tokens">Tags</label>		<input id="recipe_tag_tokens" name="recipe[tag_tokens]" rows="2" size="30" type="text" />  </div>
         <div class="edit_recipe_field" >
       		<label for="recipe_comment">Notes</label>		<textarea cols="40" id="recipe_comment" name="recipe[comment]" placeholder="What are your thoughts about this recipe?" rows="3">%%rcpComment%%</textarea>  </div>
         <div class="edit_recipe_field" >
       		<label for="recipe_title">Title</label>		<textarea cols="40" id="recipe_title" name="recipe[title]" rows="3">%%rcpTitle%%</textarea>  </div>
         <div class="edit_recipe_field">
       		<label for="recipe_status">Status: </label>		<select id="recipe_status" name="recipe[status]">
            <option value="1">Now Cooking</option>
            <option value="2">Keepers</option>
            <option value="4">To Try</option>
            <option value="8">Misc</option></select>
        </div>
        <div class="edit_recipe_field">
       		<input name="recipe[private]" type="hidden" value="0" /><input %%rcpPrivate%% id="recipe_private" name="recipe[private]" type="checkbox" value="1" />
       		<label for="recipe_private">Private (for my eyes only)</label>
         </div>
         <input class="save-tags-button submit" name="commit" type="submit" value="Save" />
         <input class="save-tags-button cancel" name="commit" type="submit" value="Cancel" />
         </form>  <form action="/recipes/%%rcpID%%/remove" class="button_to remove" data-remote="true" data-type="json" method="post"><div><input class="save-tags-button remove" type="submit" value="Remove From Collection" /><input name="authenticity_token" type="hidden" value="%%authToken%%" /></div></form>
         <form action="/recipes/%%rcpID%%" class="button_to destroy" data-remote="true" data-type="json" method="post"><div><input name="_method" type="hidden" value="delete" /><input class="save-tags-button destroy" data-confirm="This will remove the recipe from RecipePower and EVERY collection in which it appears. Are you sure this is appropriate?" type="submit" value="Destroy this Recipe" /><input name="authenticity_token" type="hidden" value="%%authToken%%" /></div></form>
      }+
    dialogFooter()
  }.to_json()
end

end
