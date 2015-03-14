require 'open-uri'
require 'json'
require './lib/Domain.rb'
require 'string_utils'

module RecipesHelper
  
  def recipe_title_div recipe
    "<div><h3>#{recipe.title}</h3></div>".html_safe
  end

  def collectible_slider_datablock decorator, cssclass="rcp_grid_datablock", &block
    entity = decorator.object
    klass = entity.class.to_s
    label = ((klass == "Recipe") || (klass == "List")) ? "" : "#{klass}: "
    itemlink = case klass
                 when "Recipe", "Site"
                   link_to decorator.title, decorator.url, class: "tablink", data: { report: polymorphic_path([:touch, entity]) } # ...to open up a new tab
                 else # Other internal entities get opened up in a new partial
                   link_to_submit decorator.title, decorator.url, mode: :partial
               end
    grid_element = content_tag :p, (label+itemlink).html_safe, class: "rcp_grid_element_title"
    case klass
      when "List"
        source_element = content_tag :div, ("a list by "+link_to_submit(decorator.owner.handle, user_path(decorator.owner, :mode => :modal))).html_safe, class: "rcp_grid_element_source"
      else
        source_element = content_tag :div, ("from "+link_to(decorator.sourcename, decorator.sourcehome, class: "tablink")).html_safe, class: "rcp_grid_element_source"
    end
    buttons_element = with_output_buffer(&block) if block_given?
    content_tag :div, "#{grid_element}#{source_element}#{buttons_element}", class: cssclass
  end

  def collectible_masonry_datablock decorator
    entity = decorator.object
    klass = entity.class.to_s
    label = ((klass == "Recipe") || (klass == "List")) ? "" : "#{klass}: "
    itemlink = case klass
                 when "Recipe", "Site"
                   link_to decorator.title, decorator.url, class: "tablink", data: { report: polymorphic_path([:touch, entity]) } # ...to open up a new tab
                 else # Other internal entities get opened up in a new partial
                   link_to_submit decorator.title, decorator.url, mode: :partial
               end
    grid_element = content_tag :p, (label+itemlink).html_safe, class: "rcp_grid_element_title"
    case klass
      when "List"
        source_element = content_tag :div, ("a list by "+link_to_submit(decorator.owner.handle, user_path(decorator.owner, :mode => :modal))).html_safe, class: "rcp_grid_element_source"
      else
        source_element = content_tag :div, ("from "+link_to(decorator.sourcename, decorator.sourcehome, class: "tablink")).html_safe, class: "rcp_grid_element_source"
    end
    content_tag :div, grid_element+source_element, class: "rcp_grid_datablock"
  end

  def collectible_info_icon decorator
    entity = decorator.object
    alltags = summarize_alltags(entity) || ""
    tags = CGI::escapeHTML alltags
    span = content_tag :span,
                "",
                class: "recipe-info-button btn btn-default btn-xs glyphicon glyphicon-open",
                data: { title: decorator.title, tags: tags, description: decorator.description || "" }
    link_to_submit span, polymorphic_path(entity), :mode => :modal
  end

  def recipe_tags_div recipe
    content_tag :div, 
      summarize_alltags(recipe) || 
      %Q{<p>...a dish with no tags or ratings in RecipePower!?! Why not #{tag_recipe_link(%q{add some}, recipe)}?</p>}.html_safe
  end

  def recipe_comments_div recipe, whose
    user = User.find recipe.collectible_user_id
    comments =
    case whose
    when :mine
      header_text = "My Comments"
      (commstr = recipe.collectible_comment) ? [ { body: commstr } ] : [] 
    when :friends
      header_text = "Comments of Friends"
      user.followee_ids.collect { |fid| 
        commstr = recipe.comment fid 
        { source: User.find(fid).handle, body: commstr } unless commstr.blank? || recipe.private(fid)
      }.compact
    when :others
      header_text = "Comments of Others"
      Rcpref.where(entity: recipe).
        where("comment <> '' AND private <> TRUE").
        where("user_id not in (?)", user.followee_ids<<user.id).collect { |rref|
          { source: rref.user.handle, body: rref.comment }
        }
    end
    return if comments.empty?
    commentstr = comments.collect { |comment| 
      srcstr = comment[:source] ? %Q{<strong>#{comment[:source]}</strong>: } : ""
      %Q{<li>#{srcstr}#{comment[:body]}</li>} unless comment[:body].blank?
    }.compact.join('')
    content_tag :div, "<h3>#{header_text}</h3><ul>#{commentstr}</ul>".html_safe
  end
  
  def grab_recipe_link label, recipe
  end

# If the recipe doesn't belong to the current user's collection,
#   provide a link to add it
def ownership_status(rcp)
	# Summarize ownership as a list of owners, each linked to their collection
	(rcp.users.map { |u| link_to u.handle, collection_path( :owner=>u.id.to_s) }.join(', ') || "").html_safe
end

  def recipe_uncollect_button recipe, browser_item
    return unless recipe && browser_item.respond_to?(:tag) && (tag = browser_item.tag)
    link_to "X",
            remove_recipe_tag_path(recipe, tag),
            method: "POST",
            remote: true,
            title: "Remove from this collection",
            class: "top_right_corner btn btn-default btn-xs"
  end

def tagjoin tags, enquote = false, before = "", after = "", joiner = ','
    strjoin tags.collect{ |tag| link_to (enquote ? "'#{tag.name}'" : tag.name), tag, class: "rcp_list_element_tag" }, before, after, joiner
end

# Provide an English-language summary of the tags for a recipe.
def summarize_alltags(taggable_entity)

    tags = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]
    taggable_entity.tags.each { |tag| tags[tag.tagtype] << tag }
    return if tags.flatten.compact.empty?
    
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
def present_comments recipe
    out = (recipe.collectible_comment) || ""
    out = "My two cents: '#{out}'<br>" unless out.empty?
    out.html_safe
end

  # Provide the cookmark-count line
  def cookmark_count(collectible_entity, user)
     count = collectible_entity.num_cookmarks
     result = count.to_s+" Cookmark"+((count>1)?"s":"")
     if collectible_entity.collected?(user.id)
        result << " (including mine)"
     else
        result << ": " + 
		  link_to("Update with Javascript Helper",
		  		 :url => {:action => "cmcount"},
				 :update => "response5")
     end
     "<span class=\"cmcount\" id=\"cmcount#{collectible_entity.id}\">#{result}</span>".html_safe
  end

end
