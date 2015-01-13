class ListItem
  include ActiveModel::Serialization

  attr_accessor :id, :klass, :entity

  def initialize(*h)
    if h.length == 1 && h.first.kind_of?(Hash)
      h.first.each { |k,v| send("#{k}=",v) }
    end
  end

  def self.load str
    hsh = {}
    str.split("\t").each { |nv| md = nv.match( /([^:]*):(.*)/); hsh[md[1].to_sym] = md[2] }
    hsh[:klass] = hsh[:klass].constantize if hsh[:klass]
    hsh[:id] = hsh[:id].to_i if hsh[:id]
    self.new hsh
  end

  def self.dump li
    str = [:id, :klass].collect { |attrsym| attrsym.to_s+":"+li.send(attrsym).to_s }.join("\t")
    str
  end

  # Entity can be accessed without loading
  def entity load=true
    @entity ||= (klass.where(id: id).first if load)
  end

  # Set the entity, caching its id and class also
  def entity=newe
    if newe  # Propogate the entity's identifying info to the rest of the item
      self.id = newe.id
      self.klass = newe.class
    end
    @entity = newe
  end

  # Does the item in the list correspond to the given entity?
  def stores? other
    (entity(false) == other) ||
    (id==other.id && klass==other.class)
  end

end

class ListSerializer

  def self.load(list_string)
    list_string ? list_string.split('\n').collect { |itemstr| ListItem::load itemstr } : []
  end

  def self.dump(list)
    list.collect { |item| ListItem::dump item }.join('\n')
  end

end

class List < ActiveRecord::Base
  include Commentable
  commentable :notes
  include Typeable
  include Collectible
  picable :picurl, :thumbnail

  typeable( :availability,
            public: ["Anyone (Public)", 0 ],
            friends: ["Friends Only", 1],
            private: ["Me only (Private)", 2]
  )

  belongs_to :owner, class_name: "User"   # The creator and default editor
  belongs_to :name_tag, class_name: "Tag"
  has_and_belongs_to_many :included_tags, class_name: "Tag"
#  has_and_belongs_to_many :subscribers, class_name: "User"
  attr_accessible :owner, :ordering, :title, :name, :name_tag_id, :name_tag, :tags, :included_tag_tokens, :pullin, :notes, :description, :availability, :owner_id
  serialize :ordering, ListSerializer

  # Using the name string, either find an existing list or create a new one FOR THE CURRENT USER
  def self.assert name, user, options={}
    puts "Asserting tag '#{name}' for user ##{user.id} (#{user.name})"
    tag = Tag.assert(name, tagtype: "List", userid: user.id)
    puts "...asserted with id #{tag.id}"
    l = List.where(owner_id: user.id, name_tag_id: tag.id).first || List.new(owner: user, name_tag: tag)
    l.save if options[:create] && !l.id
    l
  end

  def name
    (name_tag && name_tag.name) || ""
  end
  alias_method :title, :name

  def name=(new_name)
    puts "Setting name '#{new_name}'"
    oname = name_tag
    newname = Tag.assert(new_name, tagtype: "List", userid: owner.id)
    if oname != newname
      oname.dependent_lists.delete self
      self.name_tag = newname
      oname.taggings.where(user_id: owner.id).each { |tagging|
        name_tag.taggings.create tagging.attributes unless name_tag.taggings.exists? entity: tagging.entity, user_id: owner.id
        oname.taggings.destroy tagging
      }
      oname.save unless oname.safe_destroy
      name_tag.save
    end

  end
  alias_method :"title=", :"name="

  # Get all the entities from the list, in order, ignoring those which can't be fetched to cache
  def entities
    ordering.map(&:entity).compact
  end

  def entity_count
    ordering.count
  end

  # Does the list of items include the given entity?
  def stores? entity
    ordering.any? { |item| item.stores? entity }
  end

  # Ensure that the list ordering includes the given entity
  def store entity
    unless stores? entity
      ordering << ListItem.new(entity: entity)
      save
    end
  end

  def remove entity
    ordering.delete_if { |item| item.stores? entity }
    save
  end

=begin
  # This functionality allowed lists to have included tags. Now that 'pullin' gets included tags from the list's tags,
  # we don't need included tags. This may change, however
  def included_tag_tokens
    tag_ids
  end

  # Write the virtual attribute tag_tokens (a list of ids) to
  # update the real attribute tag_ids
  def included_tag_tokens=(idstring)
    self.included_tags =
        TokenInput.parse_tokens(idstring) do |token| # parse_tokens analyzes each token in the list as either integer or string
          case token
            when Fixnum
              Tag.find token
            when String
              Tag.strmatch(token, userid: tagging_user_id, assert: true)[0] # Match or assert the string
          end
        end
  end
=end

end
