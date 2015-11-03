require "templateer.rb"
class TagDecorator < Draper::Decorator
  include Templateer
  delegate_all

  def title
    object.name
  end

  # The (single) list on this tag owned by the given user
  def owned_list user
    dependent_lists.where owner_id: user.id
  end

  # Tagging by a friend on a list they own
  def friend_lists user
    # 1) All public lists owned by friends
    # 2) All friends-only lists owned by friends who also follow the user (thus allowing access to friends-only lists)
    query = "(lists.availability = 0 AND lists.owner_id in (#{user.followee_ids.join(', ')}))"
    if (extras = user.followee_ids & user.follower_ids).present?
      query << " OR (lists.availability = 1 AND lists.owner_id in (#{extras.join(', ')}))"
      puts 'extras: ', extras.sort.join(', ')
    end
    dependent_lists.where query
  end

end
