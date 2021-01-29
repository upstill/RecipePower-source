require 'open-uri'
require 'json'
require 'string_utils'

module RecipesHelper

  def recipe_title_div recipe
    "<div><h3>#{recipe.title}</h3></div>".html_safe
  end

  def collectible_title_link decorator, pclass = 'title'
    entity = decorator.object
    case entity
    when Recipe, Site
      label = ''
      itemlink = link_to decorator.title, decorator.url, class: 'tablink', data: {report: touchpath(decorator)} # ...to open up a new tab
    else # Other internal entities get opened up in a new partial
      label = "#{entity.class.to_s}: "
      itemlink = link_to_submit decorator.title, decorator.url, class: 'tablink'
    end
    content_tag :p, label.html_safe + itemlink, class: pclass
  end

  def collectible_tablink decorator
    case decorator.object
    when Recipe, Site
      link_to decorator.title, decorator.url, class: 'tablink', data: {report: touchpath(decorator)} # ...to open up a new tab
    else # Internal entities get opened up in a new partial
      link_to_submit decorator.title, decorator.object # , class: 'tablink'
    end
  end

  def collectible_source_link decorator
    if decorator.object.class == List
      label = 'a list by '
      link = link_to_dialog decorator.owner.handle, user_path(decorator.owner)
    else
      label = 'from '
      link = link_to decorator.sourcename, decorator.sourcehome, class: 'tablink'
    end
    content_tag :div, (label + link).html_safe, class: 'rcp_grid_element_source'
  end

  def collectible_masonry_datablock decorator
    title_link = collectible_title_link decorator, 'rcp_grid_element_title'
    source_element = collectible_source_link decorator
    content_tag :div, (title_link + source_element).html_safe, class: 'rcp_grid_datablock'
  end

  def collectible_info_icon decorator
    entity = decorator.object
    alltags = summarize_alltags(entity) || ''
    tags = CGI::escapeHTML alltags
    span = content_tag :span,
                       '',
                       class: 'recipe-info-button btn btn-default btn-xs glyphicon glyphicon-open',
                       data: {title: decorator.title, tags: tags, description: decorator.description || ''}
    link_to_dialog span, polymorphic_path(decorator.as_base_class)
  end

  def recipe_tags_div recipe
    content_tag :div,
                summarize_alltags(recipe) ||
                    %Q{<p>...a dish with no tags or ratings in RecipePower!?! Why not #{tag_recipe_link(%q{add some}, recipe)}?</p>}.html_safe
  end

  def recipe_comments_div recipe, whose
    user = User.current_or_guest
    comments =
        case whose
        when :mine
          header_text = 'My Comments'
          (commstr = recipe.collectible_comment) ? [{body: commstr}] : []
        when :friends
          header_text = 'Comments of Friends'
          user.followee_ids.collect { |fid|
            commstr = recipe.comment fid
            {source: User.find(fid).handle, body: commstr} unless commstr.blank? || recipe.private(fid)
          }.compact
        when :others
          header_text = 'Comments of Others'
          Rcpref.where(entity: recipe).
              where('comment <> \'\' AND private <> TRUE').
              where('user_id not in (?)', user.followee_ids << user.id).collect { |rref|
            {source: rref.user.handle, body: rref.comment}
          }
        end
    return if comments.empty?
    commentstr = comments.collect { |comment|
      srcstr = comment[:source] ? %Q{<strong>#{comment[:source]}</strong>: } : ''
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
    (rcp.collectors.map { |u| link_to u.handle, default_next_path(:owner => u.id.to_s) }.join(', ') || '').html_safe
  end

  def recipe_uncollect_button recipe, browser_item
    return unless recipe && browser_item.respond_to?(:tag) && (tag = browser_item.tag)
    link_to 'X',
            remove_recipe_tag_path(recipe, tag),
            method: 'POST',
            remote: true,
            title: 'Remove from this collection',
            class: 'btn btn-default btn-xs'
  end

  def refresh_button object
    object ?
        link_to_submit('',
                       polymorphic_path(object, refresh: true),
                       mode: :partial,
                       class: 'action-button glyphicon glyphicon-refresh',
                       title: 'Refresh Content') :
        ''.html_safe
  end

  def edit_trimmers_button object
    object ?
        link_to_submit('',
                       polymorphic_path([:edit, object], topics: :site),
                       mode: :modal,
                       class: 'action-button glyphicon glyphicon-filter',
                       title: 'Edit Trimmers') :
        ''.html_safe
  end

  def edit_recipes_button recipe_page
    recipe_page ?
        button_to_submit('',
                       edit_recipe_page_path(recipe_page, topics: :page_recipes),
                       'glyph-edit-red',
                       'lg',
                       mode: :modal,
                       class: 'action-button annotate-content', # 'action-button glyphicon glyphicon-filter',
                       title: 'Edit Trimmers') :
        ''.html_safe
  end

  def content_button object
    object ?
        button_to_submit("#{object.model_name}".html_safe, polymorphic_path(object, mode: :partial)) :
        ''.html_safe
  end

  def recipe_content_buttons object
    return unless policy(object).update?
    if [PageRef, Recipe, RecipePage, MercuryResult, Gleaning].include?(object.class)
      page_ref = object.page_ref
      buttons = ActiveSupport::SafeBuffer.new
      recipe = object.is_a?(Recipe) ? object : page_ref.recipes.first
      if response_service.admin_view?
        buttons += "#{object.class.to_s}<strong></strong>&nbsp;".html_safe
        buttons += content_button(page_ref) if object != page_ref
        buttons += content_button(recipe) if object != recipe
        buttons += content_button(page_ref.mercury_result) if object != page_ref.mercury_result
        buttons += content_button(page_ref.gleaning) if object != page_ref.gleaning
        buttons += content_button(page_ref.recipe_page) if object != page_ref.recipe_page
        buttons += refresh_button object
      end
      case object
      when Recipe
        buttons +=
            link_to_submit '',
                             recipe_page_recipe_path(object, launch_dialog: 'annotate-content' ),
                             class: 'action-button glyphicon glyphicon-asterisk',
                             mode: :partial,
                             title: 'Split Recipe',
                             method: (object.recipe_page.nil? ? 'POST' : 'GET')
        buttons +=
            button_to_submit('',
                             edit_recipe_contents_path(recipe),
                             'glyph-edit-red',
                             'xl',
                             mode: :modal,
                             class: 'action-button annotate-content',
                             title: 'Annotate Content')
        buttons += edit_trimmers_button object
      when RecipePage
        # Provide editing button if Recipe or RecipePage
        # buttons += collectible_edit_button object, 'xl', class: 'action-button annotate-content'
        buttons += edit_recipes_button object
        buttons += edit_trimmers_button object
      when PageRef
        buttons += edit_trimmers_button object
      when Gleaning
        buttons += edit_trimmers_button object
      end
      msg = 'Refresh Recipe to create Recipe Page' if !page_ref.recipe_page
      buttons += content_tag(:p, "**#{msg}.") if msg.present?
      content_tag :div, buttons, style: 'font-size: 18px; font-weight: bold;'
    end
  end

  def tagjoin tags, enquote = false, before = '', after = '', joiner = ','
    strjoin tags.collect { |tag| link_to (enquote ? "'#{tag.name}'" : tag.name), tag, class: 'rcp_list_element_tag' }, before, after, joiner
  end

# Provide an English-language summary of the tags for a recipe.
  def summarize_alltags(taggable_entity)

    tags = [[], [], [], [], [], [], [], [], [], [], [], [], [], [], [], [], [], [], [], []]
    taggable_entity.tags.each { |tag| tags[tag.tagtype] << tag }
    return if tags.flatten.compact.empty?

    genrestr = tagjoin tags[1], false, '', ' '
    rolestr = tagjoin tags[2], false, ' for '

    procstr = tagjoin tags[3], false, ' with ', ' process'
    foodstr = tagjoin tags[4], false, ' that includes '
    sourcestr = tagjoin tags[6], false, ' from '
    authorstr = tagjoin tags[7], false, ' by '
    toolstr = tagjoin tags[12], false, ' with '

    occasionstr = tagjoin tags[8], false, ' good for'
    intereststr = tagjoin tags[11], true, ' tagged by Interest for '

    otherstr = tagjoin (tags[0] + tags[13] + tags[14]), true, ' Miscellaneous tags: ', '.'

    strlist = [sourcestr, authorstr, foodstr, procstr, toolstr].keep_if { |str| !str.empty? }

    genrestr = '<span>untagged</span>' if strlist.empty? && genrestr.blank? && occasionstr.blank? && intereststr.blank? && otherstr.blank?
    if genrestr.blank?
      article = 'A'
    else
      article = (genrestr =~ />[aeiouAEIOU]/i) ? 'An ' : 'A '
    end

    ((article + genrestr + ' recipe' + (strlist.shift || '') +
        strjoin(strlist, '', '', '; ') + '.').sub(/A\s*recipe\./, '') +
        strjoin([occasionstr, intereststr], ' ', '.', ',').capitalize +
        otherstr).html_safe
  end

# Present the comments to this user. Now, all comments starting with his/hers, but ultimately those of his friends
  def present_comments recipe
    out = (recipe.collectible_comment) || ''
    out = "My two cents: '#{out}'<br>" unless out.empty?
    out.html_safe
  end

  def sequence_instructions txt
    sentences = txt.
        strip.   # No whitespace fore and aft
    # sub(/\.$/,'').
        split( /\.\s+/ ). # Break on sentences
        collect { |sentence| sentence.match(/[?!]/) ? sentence : (sentence.strip << '.') }
    while step = sentences.shift do
      break if step.present? && !step.match(/^[\d.,)]*$/)
    end
    return if sentences.blank?
    sentences.each do |sentence|
      if sentence.split(/\s+/).length > 3
        yield step if step.present?
        step = sentence
      else
        step << ' ' if step.present?
        step << sentence unless sentence.match(/^[\d.,)]*$/)
      end
    end
    yield step if step.present?
  end

# Provide the cookmark-count line
  def cookmark_count(collectible_entity, user)
    count = collectible_entity.num_cookmarks
    result = count.to_s + ' Cookmark' + ((count > 1) ? 's' : '')
    if collectible_entity.collectible_collected? user.id
      result << ' (including mine)'
    else
      result << ': ' +
          link_to('Update with Javascript Helper',
                  :url => {:action => 'cmcount'},
                  :update => 'response5')
    end
    "<span class=\"cmcount\" id=\"cmcount#{collectible_entity.id}\">#{result}</span>".html_safe
  end

end
