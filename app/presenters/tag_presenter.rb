class TagPresenter < BasePresenter
  include CardPresentation
  presents :tag

  def tagserv
    @tagserv ||= TagServices.new tag
  end

  def name withtype = false, do_link = true
    ((withtype ? "<i>#{decorator.typename}</i> " : '') +
        "'<strong>#{do_link ? h.homelink(tag) : tag.name}</strong>'").html_safe
  end

  # Provide a text meaning of a tag by getting a description from one of its referent(s), if any--preferentially the primary meaning
  def description
    (tag.meaning && tag.meaning.description.if_present) ||
        tag.meanings.pluck(:description).find(&:'present?')
  end

  def table_summaries admin_view_on
    # set = [ self.recipes_summary, self.owners, self.children, self.meanings, self.references, self.relations ]
    set = []
    NestedBenchmark.measure '...summarizing owners:' do
      set << self.summarize_aspect(:owners, :for => :table, :helper => :homelink, :limit => 5)
    end unless tagserv.is_global
    NestedBenchmark.measure '...summarizing meanings:' do
      set << self.summarize_aspect(:meanings, :for => :table, :helper => :summarize_referent)
    end
  end

  # Present a summary of one aspect of a tag (specified as a symbol in 'what'). Possibilities:
  # :owners - Users who own a private tag
  # :parents - Tags for the semantic parents of a tag
  # :children - Tags for the semantic offspring of a tag
  # :meanings - The meaning(s) attached to a tag
  # :page_refs -- A set of page Refs selected using an entry from TagServices.type_selections
  # :synonyms - Tags for the semantic siblings of a tag
  # :similars - Tags for the lexical of a tag (those which have the same normalized_name)

  # options[:for] declares a destination, one of:
  # :table - for dumping in a column of a row for the tag
  # :card - for including on a card
  # :raw - return just the strings for the elements

  # options[:helper] prescribes the name of a helper to name and possibly link to an instance of the aspect
  # options[:absorb_btn] enables the provision of a button for absorbing the other into this tag
  # options[:merge_into_btn] converse of :absorb_btn
  def summarize_aspect what, options = {}
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
          when :meanings
            tag.meanings
          when Array
            # An array from the PageRefServices select list: first is the label, second is the kind
            tagserv.page_refs_of_kind what.last
          else
            tagserv.public_send what
          end
        end
    return if scope.empty?
    options[:count] = scope.count
    scope = scope.limit(options[:limit]) if options[:limit] && (options[:limit] < options[:count])
    strs = scope.collect {|entity|
      case helper
      when :summarize_tag_similar
        btn_options = {:absorb_btn => (options[:absorb_btn] && tagserv.can_absorb(entity)),
                       :merge_into_btn => (options[:merge_into_btn] && TagServices.new(entity).can_absorb(tag))}
        h.summarize_tag_similar tag, entity, btn_options
      when :summarize_referent
        h.summarize_referent entity
      when :summarize_meaning
        h.homelink entity
      else
        h.public_send helper, entity
      end
    }
    case format.to_sym
    when :card
      h.format_card_summary strs, {label: what.to_s}.merge(options)
    when :table
      h.format_table_tree report_items(strs,
                                       (options[:label] || what.to_s.singularize.capitalize unless helper == :summarize_referent))
    when :raw
      strs
    end
  end

  # The taggees of a tag are only summarized in its table listing;
  # when shown on a card, the taggees should appear in an associated list
  def taggees_table_summary options = {}
    summs =
        NestedBenchmark.measure '...getting taggee_samples:' do
          # Provide a collection of (direct) taggees
          tag.taggings.group(:entity_type).pluck(:entity_type).collect {|entity_type|
            h.report_items(tag.taggings.includes(:entity).where(:entity_type => entity_type),
                           entity_type.capitalize,
                           limit: 5) {|tagging| h.homelink tagging.entity, truncate: 100}
          }
        end
    h.format_table_tree summs.compact.flatten(1)
  end

  def card_homelink options = {}
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
  def card_aspects which_column = nil
    aspects = [
        :description,
        :tag_synonyms,
        :tag_owners,
        :tag_similars,
        :tag_meanings,
        :tag_parents,
        :tag_children,
    # :tag_references,
    ] + [*PageRef.kinds.except(:link, :recipe)] # PageRefServices.type_selections[2..-1]
    if block_given?
      aspects.each {|aspect|
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
           return ['', (decorator.tagtype > 0 ? "... for tagging by #{decorator.typename}" : '')]
           # return ['', self.meaning || "... for tagging by #{decorator.typename}"]
         when :tag_synonyms
           label_singular = 'synonym'
           summarize_aspect :synonyms, :for => :raw, :helper => :summarize_tag_similar, absorb_btn: true
         when :tag_owners
           label = 'private to'
           # content = h.summarize_tag_owners
           summarize_aspect(:owners, :for => :raw, :helper => :homelink) unless tagserv.is_global
         when :tag_similars
           label_singular = 'similar tag'
           summarize_aspect :lexical_similars, :for => :raw, :helper => :summarize_tag_similar, absorb_btn: true
           # Only when a tag's referent can be usefully described...
         when :tag_meanings
           label_singular = 'meaning'
           summarize_aspect :meanings, :for => :raw, :helper => :summarize_meaning, label: 'Topic'
           # content = h.summarize_tag_meanings
         when :tag_parents
           label_singular = 'under category'
           # tagserv.parents.collect { |parent| h.homelink parent }
           summarize_aspect :parents, :for => :raw, :helper => :homelink
         when :tag_children
           label = 'includes'
           # tagserv.children.collect { |child| h.homelink child }
           summarize_aspect :children, :for => :raw, :helper => :homelink
         when Array
           # An array from the PageRefServices select list: first is the label, second is the kind
           label_singular = which.first.gsub(/_/, ' ').capitalize
           # The remaining "aspects" are entries from TagServices.type_selections
           summarize_aspect which, :for => :raw, :helper => :present_page_ref
         end || []).compact
    content = safe_join(itemstrs, ', ') unless itemstrs.empty?
    label = (itemstrs.count > 1 ? label_singular.pluralize : label_singular) if label_singular
    [label, content]
  end

  # Does this presenter have an avatar to present on cards, etc?
  def card_avatar?
    tagserv.images.present?
  end

  def avatar options = {}
    if image_ref = tagserv.images.first
      image_with_error_recovery image_ref.imgdata || image_ref.url
    end
  end

  def card_avatar options = {}
    avatar options
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
    user.tags.collect {|tag| tag.name}.join(', ')
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
