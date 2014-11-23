class ListServices

  attr_accessor :list

  delegate :owner, :ordering, :name, :name_tag, :tags, :notes, :availability, :owner_id, :to => :list

  def initialize list
    self.list = list
  end

  def available_to? user
    (user.id == @list.owner.id) || # always available to owner
    (user.name == "super") || # always available to super
    (@list.typesym == :public) || # always available if public
    ((@list.typesym == :friends) && (@list.owner.follows? user)) # available to friends
  end

  # Move each of the user's collections into a list
  # TODO: remove all these after collections migrate to lists
  def self.adopt_collections
    superu = User.find User.super_id
    list = nil
    # For each user that's actually a channel, create a list
    User.where('channel_referent_id > 0').each { |channel_user|
      list = List.assert channel_user.channel.name, superu, create: true
      channel_user.rcprefs.where(in_collection: true).map(&:entity).each { |entity|
        list.include(entity) unless list.include?(entity)
      }
      list.tags = channel_user.tags
      list.save
      channel_user.destroy
    }
    User.all.each { |user|
      nlists = user.rcprefs.where("entity_type = 'List'").count
      ncollections = PrivateSubscription.where("user_id = #{user.id}").count
      puts "#{user.handle} has #{ncollections} collections and #{nlists} lists before."
      subs = PrivateSubscription.where("user_id = #{user.id}")
      subs.each { |sub|
        tag = sub.tag
        list = List.assert tag.name, user, create: true
        tag.recipes(user.id).each { |entity|
          list.include(entity) unless list.include?(entity)
        }
        sub.destroy
      }
      nlists = user.rcprefs.where("entity_type = 'List'").count
      ncollections = PrivateSubscription.where("user_id = #{user.id}").count
      puts "#{user.handle} has #{ncollections} collections and #{nlists} list afterward."
    }
    ups = User.find 3
    superu.owned_lists.each { |l| ups.collect l }
    ups.save
    list
  end

  def self.study_users
    User.all.collect { |user|
      user.collection_tags.collect { |tag|
        if (ct = tag.recipes(user.id).count) > 0
          "User ##{user.id} has #{ct} recipes in #{tag.name} collection."
        end
      }+
      user.lists.collect { |list|
        if (ct = list.entity_count) > 0
          "User ##{user.id} has #{ct} recipes in #{list.name} list."
        end
      }
    }.flatten.compact.each { |str| puts str }
    ""
  end

end