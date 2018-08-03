class ReferentPresenter < CollectiblePresenter
  include CardPresentation
  presents :referent

  # Does this kind of Referent have an editable field for
  def has_editable kind
    case kind
      when :children
        false
      else
        true
    end
  end

  def card_aspects which_column=nil
    # decorator.object.is_a?(Taggable) ? decorator.individual_tagtypes : []
  [ :description, :title, :parents, :children, :relateds, :synonyms, :lists, :feeds, :sites, :about, :article, :news_item, :tip, :video, :home_page, :product, :offering, :event ]
  end

  def card_aspect which
    label = nil
    whichsym = which.to_sym
    whichstr = which.to_s.downcase.singularize
    contents =
        case whichsym
          when :parents, :children, :relateds, :expressions, :synonyms
            tags = decorator.visible_tags_of_kind whichsym, viewer
            label = I18n.t "referent.tags_labels.#{which}", name: decorator.title
            # tags = decorator.send "visible_#{whichstr}_tags" # visible_tags :tagtype => :Dish
            # label = decorator.send("#{whichstr}_tags_label")
            label = field_label_counted label, tags.count unless whichsym == :relateds
            entity_links tags, joinstr: ' | '
          when :lists
            # Lists that are tagged by an expression tag
            feeds = decorator.tagged_entities :list, @user
          when :feeds
            # Feeds that are tagged by an expression tag
            sites = decorator.tagged_entities :feed, @user
          when :sites
            # Sites given by associated PageRefs, or that are tagged by an expression tag
            sites = decorator.tagged_entities :site, @user
            label = field_label_counted 'site', sites.count
            entity_links sites, external: true
          when :about, :article, :news_item, :tip, :video, :home_page, :product, :offering, :event
            # Associated PageRefs, either direct (via Referment) or indirect (tagged by one of our tags)
            prs = decorator.page_refs whichsym
            label = (whichsym == :about) ? "About #{decorator.title}" : field_label_counted(whichsym.to_s, prs.count)
            entity_links prs, external: true, joinstr: '; '
          else
            return super
        end
    [ label, contents ]
  end

end