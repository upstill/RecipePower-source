class TagPresenter < BasePresenter
  include CardPresentation
  presents :tag

  def tagserv
    tagserv ||= TagServices.new tag
  end

  def name withtype = false, do_link = true
    ((withtype ? "<i>#{decorator.typename}</i> " : '' )+
        "'<strong>#{do_link ? h.homelink(tag) : tag.name}</strong>'").html_safe
  end

  # Provide a text meaning of a tag by getting a description from one of its referent(s), if any--preferentially the primary meaning
  def meaning
    primary_description = tagserv.primary_meaning && tagserv.primary_meaning.description
    return primary_description if primary_description.present?
    tagserv.referents.pluck(:description).find(&:'present?')
  end

  def table_summaries admin_view_on
    # set = [ self.recipes_summary, self.owners, self.children, self.referents, self.references, self.relations ]
    set = []
    set << self.summarize_aspect(:owners, :for => :table, :helper => :homelink, :limit => 5) unless tagserv.isGlobal
    set << self.summarize_aspect(:parents, :for => :table, :helper => :homelink, limit: 5)
    set << self.summarize_aspect(:children, :for => :table, :helper => :homelink, limit: 5)
    set << self.summarize_aspect(:referents, :for => :table, :helper => :summarize_referent)
    # set << self.summarize_aspect(:definition_page_refs, :for => :table, :helper => :present_definition, :label => 'Reference')
    summarize_set '', set
  end

  # Present a summary of one aspect of a tag (specified as a symbol in 'what'). Possibilities:
  # :owners - Users who own a private tag
  # :parents - Tags for the semantic parents of a tag
  # :children - Tags for the semantic offspring of a tag
  # :referents - The meaning(s) attached to a tag
  # :definition_page_refs - Any definitions using the tag
  # :synonyms - Tags for the semantic siblings of a tag
  # :similars - Tags for the lexical of a tag (those which have the same normalized_name )

  # options[:for] declares a destination, one of:
  # :table - for dumping in a column of a row for the tag
  # :card - for including on a card
  # :raw - return just the strings for the elements

  # options[:helper] prescribes the name of a helper to name and possibly link to an instance of the aspect
  def summarize_aspect what, options={}
    helper = (options.delete :helper) || :homelink
    format = (options.delete :for) || :card
    scope =
        if block_given?
          yield
        else
          case what
            # Get unique parents, children and synonyms
            when :parents
              tagserv.parents true
            when :children
              tagserv.children true
            when :synonyms
              tagserv.synonyms true
            else
              tagserv.public_send what
          end
        end
    return if scope.empty?
    options[:count] = scope.count
    scope = scope.limit(options[:limit]) if options[:limit] && (options[:limit] < options[:count])
    strs = scope.collect { |entity|
      case helper
        when :summarize_tag_similar
          h.summarize_tag_similar tag, entity, (options[:absorb_btn] && tagserv.can_absorb(entity))
        else
          h.public_send helper, entity
      end
    }
    case format.to_sym
      when :card
        h.format_card_summary strs, { label: what.to_s }.merge(options)
      when :table
        label = options[:label] || what.to_s.singularize.capitalize
        counted_label = ((strs.count > 1) ? labelled_quantity(options[:count] || strs.count, label) : label) if label.present?
        h.format_table_summary strs, counted_label
      when :raw
        strs
    end
  end

  # The taggees of a tag are only summarized in its table listing;
  # when shown on a card, the taggees should appear in an associated list
  def taggees_table_summary options={}
    taggees = tagserv.taggees
    return (options[:report_null] ? ['No Cookmarks'] : []) if taggees.empty?
    taggees.collect { |keyval|
      klass, scope = *keyval
      ct = scope.count
      label = (ct > 1) ? labelled_quantity(ct, klass.model_name.human) : klass.model_name.human
      h.format_table_summary scope.limit(5).collect { |entity| h.homelink entity, truncate: 20 }, label, options
    }
  end

  def card_homelink options={}
    h.homelink tag, options
  end

  def is_viewer?
    @viewer && (@viewer.id == user.id)
  end

  def card_header_content
    name
  end

  def card_ncolumns
    1
  end

  # Report the aspects for a card on the tag
  # If a block is given, call it for each aspect
  def card_aspects which_column=nil
    aspects = [
        :description,
        :tag_synonyms,
        :tag_owners,
        :tag_similars,
        :tag_referents,
        :tag_parents,
        :tag_children,
        :tag_references,
    ]
    if block_given?
      aspects.each { |aspect|
        yield *presenter.card_aspect(aspect)
      }
    end
    aspects
  end

  def card_aspect which
    label = label_singular = content = nil
    itemstrs =
        (case which
           when :description
             return ['', self.meaning || "... for tagging by #{decorator.typename}"]
           when :tag_synonyms
             label_singular = 'synonym'
             summarize_aspect :synonyms, :for => :raw, :helper => :summarize_tag_similar, absorb_btn: true
           when :tag_owners
             label = 'private to'
             # content = h.summarize_tag_owners
             summarize_aspect(:owners, :for => :raw, :helper => :homelink) unless tagserv.isGlobal
           when :tag_similars
             label_singular = 'similar tag'
             summarize_aspect :lexical_similars, :for => :raw, :helper => :summarize_tag_similar, absorb_btn: true
           when :tag_referents
             label_singular = 'meaning'
             summarize_aspect :referents, :for => :raw, :helper => :homelink
           # content = h.summarize_tag_referents
           when :tag_parents
             label_singular = 'under category'
             # tagserv.parents.collect { |parent| h.homelink parent }
             summarize_aspect :parents, :for => :raw, :helper => :homelink
           when :tag_children
             label = 'includes'
             # tagserv.children.collect { |child| h.homelink child }
             summarize_aspect :children, :for => :raw, :helper => :homelink
           when :tag_references
             label_singular = 'see also'
             # content = h.summarize_tag_references
             summarize_aspect :definition_page_refs, :for => :raw, :helper => :present_definition
             # tagserv.definition_page_refs.collect { |definition| h.present_definition(definition) }.compact
         end || []).compact
    content = safe_join(itemstrs, ', ') unless itemstrs.empty?
    label = (itemstrs.count > 1 ? label_singular.pluralize : label_singular) if label_singular
    [label, content]
  end

  # Does this presenter have an avatar to present on cards, etc?
  def card_avatar?
    tagserv.images.present?
  end

  def card_avatar options={}
    if image_ref = tagserv.images.first
      image_with_error_recovery image_ref.imgdata || image_ref.url
    end
  end

  def show_or_edit which, val
    if is_viewer?
      if val.present?
        (user.about + h.link_to_submit("Edit", edit_user_path(section: which), button_size: "xs")).html_safe
      else
        card_aspect_editor which
      end
    else
      val if val.present?
    end
  end

  def about
    handle_none user.about do
      markdown(user.about)
    end
  end

  def tags
    user.tags.collect { |tag| tag.name }.join(', ')
  end

  def tools_menu

  end

  private

  def handle_none(value)
    if value.present?
      yield
    else
      h.content_tag :span, "None given", class: "none"
    end
  end

end
