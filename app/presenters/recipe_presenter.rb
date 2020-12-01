class RecipePresenter < CollectiblePresenter

  # Show the avatar on a recipe card only if there's direct image data (i.e., no fallback)
  def card_show_avatar
    decorator.imgdata.present?
  end

  def card_video
    @vidlink ||=
    if decorator.url.present? &&
        (url = URI(decorator.url)) &&
        url.host &&
        url.host.match(/\.youtube.com/) &&
        (vidlink = YouTubeAddy.extract_video_id(decorator.url))

      video_embed "https://www.youtube.com/embed/#{vidlink}"
    end || ''
  end

  # Recipes don't have a ribbon on their card
  def ribbon
  end

  # Recipes don't have a tab on their card
  def card_label
  end

  # The recipe's avatar on a card can be either a video or a straight image
  def card_avatar options={}
    card_video.if_present || super
  end

  def card_aspects which_column=nil
    ([ :yield, :times ] + super).compact.uniq
  end

  def card_aspect which
    label = nil
    contents =
        case which.to_sym
          when :times
            label = 'Time'
            [ ("Prep: #{decorator.prep_time}" if decorator.prep_time.present?),
              ("Cooking: #{decorator.cook_time}" if decorator.cook_time.present?),
              ("Total: #{decorator.total_time}" if decorator.total_time.present?) ].compact.join('</br>').html_safe
          when :yield
            label = 'Yield'
            decorator.yield if decorator.yield.present?
          else
            return super
        end
    [ label, contents ]
  end

  # Present the recipe's content in its entirety.
  # THIS SHOULD HANDLED CAREFULLY b/c who knows what nefarious HTML it contains?
  def html_content
    # Handle empty content first by returning an error message
    if @object.content.blank?
      if @object.page_ref&.trimmed_content.blank?
        return "No Recipe content (PageRef content is empty)".html_safe
      elsif @object.recipe_page&.selected_content(@object.anchor_path, @object.focus_path).blank?
        return "No Recipe content (PageRef has content but RecipePage content is empty)".html_safe
      else
        return "Recipe has no content currently. Try Refreshing."
      end
    end
    hc = with_format('html') { render 'recipes/formatted_content', presenter: self, locals: { presenter: self } }
    if response_service.admin_view?
      hc + content_tag(:h2, 'Raw Parsed Content -------------------------------') + @object.content.html_safe  
    end
  end

=begin
  # Syntactic sugar to allow the view to refer to fields by name
  def method_missing namesym, *args, &block
    content = content_for :"rp_#{namesym}"
    content = block.call(content) if block_given?
    content
  end
=end

  def assemble_tree node
    return node.text.html_safe if node.text?
    content = safe_join node.children.collect { |child| assemble_tree child }
    node.classes.each do |klass|
      # For each node, see if we have ideas about how to present it
      case klass.to_sym
      when :rp_ingname
        # Wrap an ingredient tag in a link to that tag in RecipePower
        tag = Tag.find_by name: node['data-value'], tagtype: Tag.typenum(:Ingredient)
        return homelink(tag, class: 'rp_ingname') if tag
      when :rp_ingline
        return content_tag(:li, content, class: :rp_ingline )
      when :rp_amt_with_alt, :rp_presteps, :rp_condition
        return content_tag(:span, content, class: klass.to_sym )
      end
    end
    return content
  end

  def content_for token
    return if @object.content.blank?
    html =
    case token
    #when :rp_title
    #when :rp_author
    when :rp_yield, :rp_serves
      result_for ".#{token} .rp_amt"
    #when :rp_prep_time, :rp_cook_time, :rp_total_time, :rp_time
    #when :rp_ing_comment
    when :rp_inglist
      results_for(".rp_inglist") { |listnode|
        assemble_tree listnode
      }
    #when :rp_ingline
    #when :rp_instructions
    else # Default is just to return the text at the named node
      result_for ".#{token}"
    end
    # Now we give the view a chance to enclose our result
    if html.is_a?(Array)
      safe_join( html.collect { |h| block_given? ? (yield(h) if h.present?) : h }.compact )
    else
      block_given? ? (yield(html) if html.present?) : html
    end
  end

  private

  # Here's where we can 
  def extract_from_node token, txt
    if txt.present?
      txt
    end
  end

  # Find a single result for the given selector
  def result_for selector
    results_for(selector).first
  end

  # Find a collection of results for the given selector
  # The entirety of the object's content is searched by default, but
  # a node of a Nokogiri doc may be provided for limiting the scope
  def results_for selector, nkdoc=nil, &block
    nkdoc ||= (@nkdoc ||= Nokogiri::HTML.fragment @object.content)
    if block_given?
      nkdoc.css(selector).collect &block
    else
      nkdoc.css(selector).collect { |node| node.text }.keep_if(&:present?)
    end
  end

end
