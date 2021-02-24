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

  def content_preface
    (prpr = proxy_presenter) ? prpr.content_preface : super
  end

  # Present the recipe's content in its entirety.
  # THIS SHOULD HANDLED CAREFULLY b/c who knows what nefarious HTML it contains?
  def html_content
    # Handle empty content first by returning an error message
    if prpr = proxy_presenter
      return prpr.html_content
    end

    hc = if content_for(:rp_inglist).present? && content_for(:rp_instructions).present?
           with_format('html') { render 'recipes/formatted_content', presenter: self, locals: {presenter: self} }
         else
           (@object.content || '').html_safe
         end
    if response_service.admin_view? && @object.content
      hc += content_tag(:h2, 'Raw Parsed Content -------------------------------') + @object.content.html_safe
    end
    hc
  end

  def content_suggestion
    cs = <<EOF
          Ingredients, instructions and title are identified using CSS.<br>
          If the recipe page contains multiple recipes, click #{split_recipe_button @object, 'here'}
EOF
    cs.html_safe
  end

  # Assemble HTML to represent the DOM subtree denoted by node
  def assemble_tree node, selector = nil
    return node.text.html_safe if node.text?
    selection = selector ? node.css(selector) : node.children
    content = safe_join selection.collect { |child| assemble_tree child }
    node.classes.each do |klass|
      # For each node, see if we have ideas about how to present it
      case klass.to_sym
      when :rp_ingname
        # Wrap an ingredient tag in a link to that tag in RecipePower
        tag = Tag.find_by name: node['value'], tagtype: Tag.typenum(:Ingredient)
        return homelink(tag, class: 'rp_ingname', title: node.text) if tag
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
        [ assemble_tree(listnode, '.rp_ingline'),
          listnode.css('.rp_inglist_label').first&.inner_text
        ] unless listnode.ancestors.to_a[0...-1].any? { |anc|
          anc.matches? '.rp_instructions'
        }
      }.compact
    #when :rp_ingline
    when :rp_instructions
      # The instructions will be probed for embedded ingredient(list)s, and those interspersed in the text.
      result = result_for ".#{token}"
      result.strip.sub(/\.$/,'')+'.' if result.present?
    else # Default is just to return the text at the named node
      result_for ".#{token}"
    end
    # Now we give the view a chance to enclose our result
    if html.is_a?(Array)
      safe_join html.collect { |h|
        if block_given?
          if h.is_a?(Array)
            yield *h
          else
            yield h
          end
        else
          h
        end
      }.compact
    else
      block_given? ? (yield(html) if html.present?) : html
    end
  end

  # Break instructions into a sequence of <li> tags
  def present_instructions
    prior_line = nil
    instructions_results do |instrs_or_ingline|
      if instrs_or_ingline.is_a?(String)
        sequence_instructions(instrs_or_ingline) do |line|
          yield content_tag :li, prior_line if prior_line
          prior_line = line
        end
      elsif instrs_or_ingline.matches?('.rp_ingline')
        if prior_line
          yield content_tag :li, prior_line.sub(/\.$/, ':')
          prior_line = nil
        end
        yield assemble_tree(instrs_or_ingline)
      end
    end
    yield content_tag :li,  prior_line.sub(/\.*$/, '.') if prior_line
  end

  # Look out for ingredient(list)s embedded in the instructions; yield to the block for each:
  # -- strings to be turned into instruction lists
  # -- ingredient lists and lines to be interspersed therein
  def instructions_results
    results_for('.rp_instructions') do |node|
      prev_ilist = nil
      node.css('.rp_ingline').each { |ingline_node|
        intervening_text = nknode_text_before(nknode_first_text_element(ingline_node), within: node, starting_after: prev_ilist)
        yield intervening_text if intervening_text.present?
        prev_ilist = ingline_node
        yield ingline_node
      }
      yield (prev_ilist ? nknode_text_after(prev_ilist, within: node) : node.text)
    end
  end

  private

  def proxy_presenter
    return @prpr if @prpr
    @object.ensure_attributes :content
    @prpr =
    if @object.content.blank?
      if @object.page_ref&.gleaning.content.blank?
        GleaningPresenter.new @object.page_ref&.gleaning, @template, @viewer
      elsif @object.page_ref&.trimmed_content.blank?
        PageRefPresenter.new @object.page_ref, @template, @viewer
      end
    end
  end

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
