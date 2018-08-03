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
    whichsym = which.to_sym
    whichstr = which.to_s.downcase.singularize
    label = I18n.t "referent.card_labels.#{which}", name: decorator.title
    counted_label = nil
    link_options = {}
    collection =
        case whichsym
          when :parents, :children, :relateds, :expressions, :synonyms
            counted_label = label if whichsym == :relateds
            link_options[:joinstr] = ' | '
            decorator.visible_tags_of_kind(whichsym, viewer)
          when :lists, :feeds, :sites
            # Lists that are tagged by an expression tag
            link_options[:external] = whichsym == :sites
            decorator.tagged_entities whichstr, @user
          when :about, :article, :news_item, :tip, :video, :home_page, :product, :offering, :event
            # Associated PageRefs, either direct (via Referment) or indirect (tagged by one of our tags)
            counted_label = label if whichsym == :about
            link_options[:external] = true
            link_options[:joinstr] = '; '
            decorator.page_refs whichsym
          else
            return super
        end
    [
        (counted_label || field_label_counted(label, collection.count)),
        entity_links(collection, link_options)
    ]
  end

end