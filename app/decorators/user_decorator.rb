# require "templateer.rb"
class UserDecorator < CollectibleDecorator
  # include Templateer
  # delegate_all

  def title
    h.user_linktitle object
  end

  def sourcename
    ""
  end

  def sourcehome
    ""
  end

  def description
    object.about
  end

  # Filter the user's taggings by entity_type
  def owned_taggings entity_type=nil
    entity_type ? user.owned_taggings.where(entity_type: entity_type.to_s) : user.owned_taggings
  end

  def owned_tags entity_type=nil
    Tag.where id: owned_taggings(entity_type).pluck(:tag_id)
  end

  # Get the entities of a given type tagged by the user
  def tagged_entities entity_type=nil
    owned_taggings(entity_type).map &:entity
  end

  # Is the object an alias for another user
  def aliases_to? user_or_id
    object.alias_id == (user_or_id.is_a?(Fixnum) ? user_or_id : user_or_id.id)
  end

  # If a user is aliased to another, return the latter
  def or_alias
    object.alias || object
  end

  # Get the user's Rcprefs that point to a given entity_type and/or are visible by a specific user
  def collection_pointers entity_type=nil, viewer=user
    if entity_type.is_a? User
      entity_type, viewer = nil, entity_type
    end
    scope = (viewer == user) ? user.collection_pointers : user.public_pointers
    scope = (scope.where entity_type: entity_type.to_s) if entity_type
    scope
  end

  # Return the set of entities of a given type that the user has collected, as visible to some other
  def collection_entities entity_type, viewer=user
    # collection_pointers(entity_type, viewer).map &:entity
    rrq = { user_id: user.id }
    rrq[:private] = false if viewer != user
    entity_type = entity_type.to_s.constantize unless entity_type.is_a? Class
    entity_type.joins(:user_pointers).where(rcprefs: rrq)
  end

  def list_availability viewer
    if user == viewer
      [0, 1, 2]
    else
      user.follows?(viewer) ? [0,1] : 0
    end
  end

  # Return the set of lists that the user has collected, as visible to some other viewer
  # NB: excludes lists that the user owns
  def collection_lists viewer=user
    scope = collection_entities(List, viewer).where.not(owner_id: user.id)
    scope = scope.where(availability: list_availability(viewer)) if user != viewer
    scope
  end
  alias_method :collected_lists, :collection_lists

  # What lists that I own can be seen by the viewer?
  def owned_lists viewer=user
    # Fall through to the full scope if no viewer is asserted
    scope = user.owned_lists
    scope = scope.where(availability: list_availability(viewer)) if user != viewer
    scope
  end

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end
  # Report all the tags in use, visible to the user.
  # The result is Struct with fields for tag_id, the name of the owner, and whether the owner is a friend
  def list_tags decorator=nil, options={}
    decorator, options = nil, decorator if decorator.is_a? Hash
    # define method to add to the results array
    def assert_tag tag, user=nil, status=nil
      return if @results[tag.id]
      sortval = case status
                  when :'my own'
                    1
                  when :'my collected'
                    2
                  when :'owned'
                    3
                  when :'collected'
                    4
                  else
                    5
                end
      result = {
          id: tag.id,
          name: tag.name,
          sortval: sortval
      }
      result[:status] = status if status
      result.merge!(
          owner_id: user.id,
          owner_name: user.handle
      ) if user
      @results[tag.id] = result
      @tag_ids_used << tag.id
    end

    @results = [] # Initialize the @results
    @tag_ids_used = []

    if decorator
      # The lists that the given object appear on FOR THIS USER are those that
      # are tagged either by the user or by the list owner (TODO or Super?)
      decorator.taggings(:List, user).includes(:tag, :entity).each { |tagging|
        # For each tagging by the user
        assert_tag tagging.tag,
                   self,
                   (tagging.entity.owner == self ? :'my own' : :'my collected')
      }
      decorator.tags(:List).each { |list_tag|
        td = list_tag.decorate
        if prime_list = td.friend_lists(user).first
          # Tagging by a friend on a list they own
          assert_tag list_tag, prime_list.owner, :owned
        elsif td.public_lists.exists? # There's at least one publicly available list using this tag as title
          assert_tag list_tag
        end
      }
    else
      owned_lists.includes(:name_tag).map(&:name_tag).each { |tag|
        assert_tag tag, self, :'my own'
      }
      collected_lists.includes(:name_tag).map(&:name_tag).each { |tag|
        assert_tag tag, self, :'my collected'
      }
      followees.each { |friend|
        friend.decorate.owned_lists(user).includes(:name_tag).map(&:name_tag).each { |tag|
          assert_tag tag, friend, :'owned'
        }
      }
      followees.each { |friend|
        friend.decorate.collected_lists(user).includes(:name_tag).map(&:name_tag).each { |tag|
          assert_tag tag, friend, :'collected'
        }
      }
      if options[:exhaustive]
        # All other public list tags
        List.where(availability: 0).where.not(name_tag_id: @tag_ids_used).includes(:name_tag).map(&:name_tag).each { |tag|
          assert_tag tag
        }
      end
    end
    # Now sort @results by ownership
    @results.compact.sort { |h1, h2| h1[:sortval] <=> h2[:sortval] }
  end

end
