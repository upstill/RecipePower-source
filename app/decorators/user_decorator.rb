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
      decorator.list_tags.each { |list_tag|
        if prime_list = list_tag.dependent_lists.where(availability: [0,1], owner_id: followee_ids).first
          # Tagging by a friend on a list they own
          assert_tag list_tag, prime_list.owner, :owned
        elsif list_tag.dependent_lists.where(availability: 0).exists? # There's at least one publicly available list
          assert_tag list_tag
        end
      }
    else
      owned_lists.each { |list|
        assert_tag list.name_tag, self, :'my own'
      }
      collected_lists.each { |list|
        assert_tag list.name_tag, self, :'my collected'
      }
      followees.each { |friend|
        friend.owned_lists.where(availability: [0,1]).each { |list|
          assert_tag list.name_tag, friend, :'owned'
        }
      }
      followees.each { |friend|
        friend.collected_lists.where(availability: 0).each { |list|
          assert_tag list.name_tag, friend, :'collected'
        }
      }
      if options[:exhaustive]
        # All other list tags
        Tag.where(tagtype: 16).
            where.not(id: @tag_ids_used).
            joins('INNER JOIN lists ON lists.name_tag_id = tags.id and lists.availability = 0').each { |tag|
          assert_tag tag if tag.public_lists.exists?
        }
      end
    end
    # Now sort @results by ownership
    @results.compact.sort { |h1, h2| h1[:sortval] <=> h2[:sortval] }
  end

end
