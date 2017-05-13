# require "templateer.rb"
class UserDecorator < CollectibleDecorator
  # include Templateer
  # delegate_all

  def title
    h.user_linktitle object
  end

  def sourcename
    ''
  end

  def sourcehome
    ''
  end

  def description
    object.about
  end

  # Check permissions for current user to access controller method
  def user_can? what
    (what.to_sym == :edit) && (object.collectible_user_id == object.id) ? true : super
  end

  def finderlabels
    super << 'Image'
  end

  def assert_gleaning gleaning
    super
    gleaning.extract1 'Image' do |value| object.image = value end
  end

  def first_collector
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

  # Get the user's Rcprefs that point to a given entity_type (or types, in an Array) and/or are visible by a specific user
  def collection_pointers entity_type_or_types=nil, viewer=user
    if entity_type_or_types.is_a? User
      entity_type_or_types, viewer = nil, entity_type_or_types
    end
    scope = (viewer == user) ? user.collection_pointers : user.public_pointers
    if entity_type_or_types.is_a? Array
      scope.where entity_type: entity_type_or_types.map(&:to_s)
    elsif entity_type_or_types
      scope.where entity_type: entity_type_or_types.to_s
    else
      scope
    end
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
    collection_entities(List, viewer).where ListServices.availability_query(viewer) # Only expose lists that are visible to the viewer
  end
  alias_method :collected_lists, :collection_lists

  # What lists that I own can be seen by the viewer?
  def owned_lists viewer=user
    # Fall through to the full scope if no viewer is asserted
    scope = user.owned_lists
    scope = scope.where(ListServices.availability_query(viewer)) if user != viewer
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
      user, status = nil, user if !user.is_a?(User)
      return if !tag || @results[tag.id]
      result = {
          tag: tag,
          id: tag.id,
          name: tag.name,
          sortval: case status
                     when :owned
                       1
                     when :collected
                       2
                     when :friends
                       3
                     when :public
                       4
                     else
                       5
                   end
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
      ListServices.associated_lists(decorator, user) do |list, status|
        assert_tag list.name_tag, list.owner, status
      end
    else
      owned_lists.includes(:name_tag).map(&:name_tag).each { |tag|
        assert_tag tag, self, :owned
      }
      collected_lists.includes(:name_tag, :owner).each { |list|
        assert_tag list.name_tag, list.owner, :collected
      }
      followees.each { |friend|
        friend.decorate.owned_lists(user).includes(:name_tag).map(&:name_tag).each { |tag|
          assert_tag tag, friend, :friends
        }
      }
      followees.each { |friend|
        friend.decorate.collected_lists(user).includes(:name_tag).map(&:name_tag).each { |tag|
          assert_tag tag, friend, :friends
        }
      }
      if options[:exhaustive]
        # All other public list tags
        List.where(availability: 0).where.not(name_tag_id: @tag_ids_used).includes(:name_tag, :owner).each { |list|
          assert_tag list.name_tag, list.owner, :public
        }
      end
    end
    # Now sort @results by ownership
    @results.compact.sort { |h1, h2| h1[:sortval] <=> h2[:sortval] }
  end

end
