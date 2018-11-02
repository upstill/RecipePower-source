class TagServices

  attr_accessor :tag
  
  delegate :id, :typename, :name, :normalized_name, :isGlobal, :taggings,
           :meaning, :primary_meaning, :elide_meaning,
           :absorb, :can_absorb,
           :users, :user_ids, :owners, :owner_ids, :to => :tag
  
  def initialize(tag, user=nil)
    self.tag = tag
    @user = user || User.super_id
  end

  def referents exclude_self=false
    exclude_self ? tag.referents.where.not(id: tag.referent_id) : tag.referents
  end

# -----------------------------------------------
  def sites
    tag.typesym == :Source ? Site.where(referent_id: tag.referent_ids) : Site.where(id: tag.site_ids)
  end
# -----------------------------------------------
  def recipe_ids with_synonyms=false
    with_synonyms ?
        Tag.where(id: ([id] + synonym_ids) ).collect { |tag| tag.recipe_ids }.flatten.uniq :
        tag.recipe_ids
  end

  def recipes with_synonyms=false
    Recipe.where(id: recipe_ids(with_synonyms) )
  end

# -----------------------------------------------
  def taggee_ids with_synonyms=false
    id_or_ids = with_synonyms ? synonym_ids : id
    taggings.where(tag_id: id_or_ids).pluck(:entity_type, :entity_id).inject({}) { |memo, pair|
      (memo[pair.first] ||= []) << pair.last
      memo
    }
  end

  def taggees with_synonyms=false
    taggee_ids(with_synonyms).inject({}) { |memo, keyval|
      klass = keyval.first.constantize
      memo[klass] = klass.where(id: keyval.last)
      memo
    }
  end

# -----------------------------------------------

  # Get all the PageRefs associated with the tag, which consists of two populations
  # 1) PageRefs that are tagged explicitly by the tag and--possibly, depending on with_synonyms--its synonyms
  # 2) PageRefs that are linked to the tag's referent(s)
  def page_refs_of_kind kind
    # entity_class = entity_class_name.constantize
    # id_or_ids = with_synonyms ? synonym_ids : id
    synids = synonym_ids true
    if synids.present?
      assoc = PageRef.of_kind(kind).joins(:taggings).where("taggings.tag_id in (#{(synids << id).join(',')})")
    else
      assoc = PageRef.of_kind(kind).joins(:taggings).where("taggings.tag_id = #{id}")
    end
    referred_page_refs = tag.referents(true).collect { |referent| referent.page_refs.of_kind kind }.flatten.uniq
    (assoc.to_a + referred_page_refs).compact
  end
# -----------------------------------------------
  def synonym_ids unique=false
    ids = ExpressionServices.synonym_ids_of_tags(id, unique)
    unique ? ids - [id] : ids
  end
  
  def self.synonym_ids(ids_in, unique=false)
    ids = ExpressionServices.synonym_ids_of_tags(ids_in, unique)
    unique ? ids - [ids_in].flatten : ids
  end
  
  def synonyms unique=false
    Tag.where id: synonym_ids(unique)
  end
# -----------------------------------------------  
  def child_ids unique=false
    ExpressionServices.child_ids_of_tags(id, unique) - [id]
  end
  
  def self.child_ids(ids)
    ExpressionServices.child_ids_of_tags(ids) - [ids].flatten
  end
  
  def children unique=false
    Tag.where id: child_ids(unique)
  end
# -----------------------------------------------    
  def parent_ids unique=false
    ExpressionServices.parent_ids_of_tags id, unique
  end
  
  def self.parent_ids ids, unique=false
    ExpressionServices.parent_ids_of_tags ids, unique
  end

  def parents unique=false
    ExpressionServices.parent_tags_of_tags id, unique
    # Tag.where id: parent_ids
    # pi.collect { |parent_set| Tag.where id: parent_set }
    # Tag.where id: parent_ids
  end

# Ensure that the child tag has a referent that is a child of our referent
# Return: the child tag
  def make_parent_of child_tag, move=true
    # NB: If the child needs to change type, and if there is a name clash with an existing type,
    # Tag.assert WILL RETURN A TAG DIFFERENT THAN THAT PROVIDED. Thus,
    # THE RETURN VALUE OF THIS METHOD NEEDS TO BE ATTENDED TO
    # In the event of failure, any errors are attached to the tag returned, which may be the original tag
    if child_tag == tag
      tag.errors.add :id, 'refers to the same tag'
      tag
    else
      begin
        Tag.transaction do
          child_tag = Tag.assert child_tag, tag.tagtype
          if child_tag == tag # We MAY have mapped an untyped tag onto our new "parent" => act as absorb
            tag
          else
            child_ref = Referent.express child_tag
            (child_tag.referent_ids & tag.referent_ids).each { |exid|
              # child_tag and tag are synonyms on some referent(s), so child needs to be removed from those refs
              child_tag.elide_meaning child_tag.referents.find_by(id: exid)
              child_ref = nil if child_ref.id == exid # Can't use a referent of the parent as the child's referent
            }
            # Force the creation of a new meaning for the child if it was a synonym of the parent
            child_ref ||= Referent.express child_tag, force: true
            parent_ref = Referent.express tag
            parent_ref.make_parent_of child_ref, move
            # Raise an error to back out of the whole thing
            raise parent_ref.errors.full_messages.join("\n") if parent_ref.errors.any?
            child_tag.save
            raise child_tag.errors.full_messages.join("\n") if child_tag.errors.any?
            parent_ref.save
            child_ref.save
            child_tag
          end
        end
      rescue => e
        tag.errors.add :child, "#{child_tag.name} can't be added to #{tag.name}: #{e}"
        tag
      end
    end
  end

# -----------------------------------------------
  def suggests target_tag
    self.express(tag).suggests self.express(target_tag)
  end

  def suggests? target_tag
    self.express(tag).suggests? self.express(target_tag)
  end

  def child_referents
    tag.referents.collect { |referent| referent.children.to_a }.flatten.uniq
  end
# -----------------------------------------------
  # Look up all the images attached to all the referents of the tag
  def images
    tag.referents.collect { |referent| referent.image_refs.to_a }.flatten
  end

  def has_image image_ref
    tag.referents.each { |referent|
      referent.image_refs << image_ref unless referent.image_refs.include?(image_ref)
    }
  end

  # Can the associated tag have its type changed?
  def retypeable?
    !(parent_ids.present? || child_ids.present?)
  end

# Given a name (or the tag thereof), ensure the existence of:
# -- a tag of the tagtype
# -- a referent "defining" that kind of entity
# -- a page_ref to the page for such a definition
# -- optionally, an ImageReference for that entity
  def self.define tag_or_tagname, options={}
    return nil unless tag_or_tagname
    page_link = options[:page_link]
    page_ref = options[:page_ref]
    tag_ref = options[:tag_ref]
    image_link = options[:image_link]
    location = nil
    return nil unless tag =
        Tag.transaction do
          tag =
              if tt = options[:tagtype]
                # Force the existence of a tag of the given type
                Tag.assert(tag_or_tagname, tt) if tag_or_tagname.present?
              elsif tag_or_tagname.is_a?(Tag)
                tag_or_tagname
              end
          if tag
            # We optionally take an existing referent to apply
            if tag_ref
              tag_ref.express tag
            else
              # No such referent? Make one!
              tag_ref = Referent.express tag
            end
            location =
                # We accept either a uri or a complete page_ref
                if page_link || page_ref
                  # Asserting the page_ref ensures a referent for the tag # Referent.express(tag) if tag.referents.empty?
                  page_ref ||= PageRef.fetch page_link
                  page_ref.kind = (options[:page_kind] || :about ) unless page_ref.persisted?
                  page_ref.assert_referent tag_ref if page_ref.errors.empty?
                  page_ref.link_text = options[:link_text].strip if options[:link_text].present? # Force the link text to something else
                  page_ref.save! if page_ref.changed?
                  page_ref.url
                else
                  '(no page_ref)'
                end
          end
          tag
        end
    unless tag_or_tagname.is_a?(Tag)
      msg = "!!!Scraper Defined #{tag.typename} link to #{tag.name} (Tag ##{tag.id}) at #{location}"
      msg << " with image #{image_link}" if image_link.present?
      Rails.logger.info msg
    end
    if parent_tag = options[:kind_of]
      parent_tag = self.define parent_tag, options.slice(:tagtype)
      Rails.logger.info "!!!Scraper  ...made '#{tag.name}' a kind of '#{parent_tag.name}'"
      TagServices.new(parent_tag).make_parent_of tag
    end
    if source_tag = options[:suggested_by]
      source_tag = self.define source_tag, options.slice(:tagtype)
      Rails.logger.info "!!!Scraper  ...noted that '#{tag.name}' is suggested by '#{source_tag.name}'"
      TagServices.new(source_tag).suggests tag
    end
    if target_tag = options[:suggests]
      target_tag = self.define target_tag, options.slice(:tagtype)
      Rails.logger.info "!!!Scraper  ...noted that '#{tag.name}' suggests '#{target_tag.name}'"
      suggests target_tag
    end
    if options[:description].present?
      tag.referents.each { |ref|
        unless ref.description.present?
          ref.description = options[:description]
          ref.save
        end
      }
    end
    has_image ReferenceServices.assert_image_for_referent(image_link, tag) if image_link
    tag
  end

# -----------------------------------------------
  # Return tags that match any of the given tags lexically, regardless of type
  # TODO: this should only address taggable tags
=begin
  def self.lexical_similars(tags)
    results = tags
    tags.each do |tag| 
      matches = Tag.strmatch(tag.name)
      results = results + (matches-results) if matches
    end
    results
  end
=end

# Return tags that match the tag lexically, regardless of type
  def lexical_similars
    Tag.taggables.where(normalized_name: normalized_name).where.not(id: id).to_a
  end
  
  def similar_ids
    relation_or_array = Tag.strmatch tag.name
    ids = relation_or_array.is_a?(Array) ? relation_or_array.map(&:id) : relation_or_array.pluck(:id)
    ids.keep_if { |candidate| candidate != id }
  end
      
# -----------------------------------------------      
  # Analyze the tag or set of tags for semantic neighbors, returning a list of 
  # tag/weight pairs.
  # ...a tag in the original set and its synonyms get a weight of 1
  # ...semantic children of the originals get weight 1/2
  # ...semantic parents of the originals get weight 1/3
  def self.semantic_neighborhood(tag_ids, min_weight = 0.4)
    result = Hash.new
    new_tag_ids = self.synonym_ids tag_ids
    weight = 1.0
    until new_tag_ids.empty? || (weight < min_weight) do
      new_tag_ids.each { |tagid| result[tagid] = weight }
      new_tag_ids = self.child_ids(new_tag_ids) - result.keys
      weight = weight/2
    end
    result
  end


  # Class method meant to be run from a console, to clean up redundant tags (name/index pair not unique) before adding index to prevent them
  def self.qa
    Tag.all.each do |tag|
      if !tag.tagqa
        if tag.errors[:key] && other = clashing_tag
          other.absorb tag
        end
      end
    end
  end

  def self.time_lookup ix=1
    label = ""
    index_name = index_table = nil
    tag_ids = Tag.all.map(&:id)
    time = Benchmark.measure do
      case ix
        when 1
          label = "Tag via ID"
          index_table = :tags
          index_name = "tags_index_by_id"
          tag_ids.each { |id|
            name = Tag.find(id).name
          }
        else
          return false
      end
    end
    index_status = ActiveRecord::Base.connection.index_name_exists?( index_table, index_name, false) ? "indexed" : "unindexed"
    File.open("db_timings", 'a') { |file|
      file.write(label+" (#{Time.new} #{index_status}): "+time.to_s+"\n")
    }
    true
  end

  # Study the Yummly dataset for correspondence with RecipePower's
  def self.yumm
    file = File.read "yumm.json"
    # ingreds = JSON.parse file
    results = ingreds.collect { |ingred|
      tags = Tag.strmatch ingred["term"], matchall: true
      (tags.empty? ? "No match on #{ingred["term"]}" : "Matched #{ingred["term"]}:")+
          tags.collect { |tag| "\n\t#{tag.typename} #{tag.id}: #{tag.name}"}.join('')
    }.sort { |line1, line2| line1 <=> line2 }
    results.each { |line| puts line }
    total = results.count
    nmatched = results.keep_if { |result| result.match /^Matched/ }.compact.count
    puts "Matched #{nmatched} of #{total}."
  end

end
