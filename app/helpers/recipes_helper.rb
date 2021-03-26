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

  def edit_trimmers_button object, label=''
    return ''.html_safe unless object
    options = { mode: :modal, title: 'Edit CSS Filters' }
    path = polymorphic_path [:edit, object], topics: :site
    if label.blank?
      options[:class] = 'action-button edit-filters'
      # options[:class] = 'action-button glyphicon glyphicon-filter' if label.blank?
      button_to_submit image_tag('CSS Logo.svg'), path, options
    else
      link_to_submit label, path, options
    end
  end

  def split_recipe_button recipe, label = ''
    return ''.html_safe unless recipe
    options = {
        mode: :partial,
        title: 'Split Recipe',
        method: (recipe.recipe_page.nil? ? 'POST' : 'GET')
    }

    options[:class] = 'action-button glyphicon glyphicon-list-alt' if label.blank?

    link_to_submit label,
                   recipe_page_recipe_path(recipe, launch_dialog: 'annotate-content'),
                   options
  end

  def edit_recipes_button recipe_page, label=''
    return ''.html_safe unless recipe_page
    options = { mode: :modal, title: 'Edit Trimmers' }
    if label.present?
      link_to_submit label, edit_recipe_page_path(recipe_page, topics: :page_recipes)
    else
      button_to_submit '',
                       edit_recipe_page_path(recipe_page, topics: :page_recipes),
                       'glyph-edit-red',
                       'lg',
                       options.merge(class: 'action-button annotate-content')
    end
  end

  def content_button_label object
    label =
    case object
    when Gleaning
      'Raw Page<br>Content'
      # when MercuryResult
    when PageRef
      'Trimmed Page<br>Content'
    when Recipe
      'Recipe As<br>Presented'
    when RecipePage
      'Recipe<br>Set'
    else
      object.model_name.human
    end
    label.html_safe
  end

  # Offer a selection of forms for the recipe's content
  def content_button object, is_present=false
    return '&nbsp;'.html_safe + content_tag( :strong, content_button_label(object)) + '&nbsp;'.html_safe if is_present
    object ?
        button_to_submit(content_button_label(object), polymorphic_path(object, mode: :partial)) :
        ''.html_safe
  end

  def recipe_content_buttons object
    return ''.html_safe unless policy(object).update? && [PageRef, Recipe, RecipePage, MercuryResult, Gleaning].include?(object.class)

    page_ref = object.page_ref
    recipe_page = page_ref.recipe_page
    recipe = object.is_a?(Recipe) ? object : page_ref.recipes.first

    buttons = ActiveSupport::SafeBuffer.new
    if response_service.admin_view?
      buttons += edit_trimmers_button object
      buttons += content_button page_ref.gleaning, object == page_ref.gleaning
      buttons += content_button page_ref, object == page_ref
      buttons += content_button(recipe, object == recipe) if recipe
      buttons += content_button(recipe_page, object == recipe_page) if recipe_page
      buttons += refresh_button object
    end

    # The object may provide an "edit" button
    if case object
       when Recipe
         # A recipe can be annotated
         edit_path, hoverprompt = edit_recipe_contents_path(recipe), 'Annotate Content'
       when RecipePage
         # A recipe page can take directions for dividing the page
         edit_path, hoverprompt = edit_recipe_page_path(object, topics: :page_recipes), 'Demarcate Recipes'
       end
      buttons +=
          button_to_submit('',
                           edit_path,
                           'glyph-edit-red',
                           'xl',
                           mode: :modal,
                           class: 'action-button annotate-content',
                           title: hoverprompt)
    end
    content_tag :div, buttons, style: 'font-size: 18px; font-weight: bold;'
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

# For a (possibly long) text string, break it into sentences and call the block for each.
  def sequence_instructions txt
    sentences = txt.
        gsub(/[[:space:]]+/, ' '). # Replace all sequences of whitespace with a single blank
        strip.   # No whitespace fore and aft
        split( /\. / ). # Break on sentences
        collect { |sentence| sentence.match(/[?!]/) ? sentence : (sentence.strip << '.') }
    while step = sentences.shift do
      break if step.present? && !step.match(/^[\d.,)]*$/)
    end
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
