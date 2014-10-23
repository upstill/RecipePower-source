class ListServices

  attr_accessor :list

  delegate :owner, :ordering, :subscribers, :name, :name_tag, :tags, :notes, :availability, :owner_id, :to => :list

  def initialize list
    self.list = list
  end

  # A list is visible to a user if:
  def subscribed_by? user
    user.list_ids.include? @list.id
  end

  def subscribe user
    @list.subscribers = @list.subscribers+[user] unless @list.subscribers.include? user
  end

  def self.subscribed_by user
    user.lists
  end

  def available_to? user
    (user.id == @list.owner.id) || # always available to owner
    (user.name == "super") || # always available to super
    (@list.typesym == :public) || # always available if public
    ((@list.typesym == :friends) && (@list.owner.follows? user)) # available to friends
  end

  # Move each of the user's collections into a list
  # TODO: remove all these after collections migrate to lists
  def self.adopt_collections u=nil
    superu = User.find User.super_id
    channel_list = user_list = []
    if !u
      channel_list = User.where('channel_referent_id > 0')
      user_list = User.where('channel_referent_id = 0')
    elsif u.channel?
      channel_list = [u]
    else
      user_list = [u]
    end
    list = nil
    channel_list.each { |user|
      list = List.assert user.channel.name, superu, create: true
      user.entities.each { |entity|
        list.include(entity) unless list.include?(entity)
      }
      list.tags = user.tags
      list.save
    }
    user_list.each { |user|
      if user.id != User.super_id
        user.collection_tags.each { |tag|
          list = List.assert tag.name, user, create: true
          tag.recipes(user.id).each { |entity|
            list.include(entity) unless list.include?(entity)
          }
        }
      end
    }
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