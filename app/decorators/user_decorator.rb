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
      decorator.taggings.joins(
        'INNER JOIN tags ON tags.tagtype = 16'
      ).where(user_id: id).each { |tagging|
        # For each tagging by the user
        list = tagging.entity
        assert_tag tagging.tag,
                   self,
                   (list.owner == self ? :'my own' : :'my collected')
      }
      # Get the set of lists where the owner has tagged the entity
      #      List.joins(
      #          'INNER JOIN taggings ON tagging.user_id = lists.owner_id'
      #      ).where(entity: decorator.object).each { |list|
      decorator.taggings.joins(
                       'INNER JOIN lists ON taggings.user_id = lists.owner_id'
      ).each { |tagging|
        if followee_ids.include? tagging.user_id
          # Tagging by a friend on a list they own
          assert_tag tagging.tag, tagging.user, :'owned'
        else
          assert_tag tagging.tag
        end
      }
    else
      owned_lists.each { |list|
        assert_tag list.name_tag, self, :'my own'
      }
      list_collections.each { |list|
        assert_tag list.name_tag, self, :'my collected'
      }
      followees.each { |friend|
        friend.owned_lists.each { |list|
          assert_tag list.name_tag, friend, :'owned'
        }
      }
      followees.each { |friend|  # TODO This is invoking a JOIN for each followee => BAD
        friend.list_collections.each { |list|
          assert_tag list.name_tag, friend, :'collected'
        }
      }
      if options[:exhaustive]
        # All other list tags
        Tag.unscoped.where(tagtype: 16).not(id: @tag_ids_used).each { |tag|
          assert_tag tag if List.exists? availability: 0, name_tag_id: tag.id
        }
      end
    end
    # Now sort @results by ownership
    @results.compact.sort { |h1, h2| h1[:sortval] <=> h2[:sortval] }
  end

end
