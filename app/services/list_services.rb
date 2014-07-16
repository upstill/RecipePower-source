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

end