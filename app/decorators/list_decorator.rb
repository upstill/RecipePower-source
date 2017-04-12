require "templateer.rb"
class ListDecorator < CollectibleDecorator
  include Templateer
  delegate_all

  def sourcename
    ''
  end

  def sourcehome
    ''
  end

  def url
    ''
  end

  def description fallback=false
    @object.description.or_fallback {
      @object.name_tag.present? ?
      case @object.name_tag.name
        when 'Keepers'
          'Recipes that are clearly worthwhile.'
        when 'Favorites'
          'The best in my collection.'
        when 'Now Cooking'
          'Recipes in active rotation.'
        when 'To Try'
          'Earmarked for later.'
      end : "Bogus list ##{@object.id}"
    }
  end

  def notes fallback=false
    @object.notes
  end

  def extract fieldname
    case fieldname.downcase
      when 'url'
        ''
    end
    super
  end

  def imgdata
    if (img = @object.imgdata).blank?
      # The default fallback is to use an image from a member of the list
      sco = ListServices.new(@object).tagging_scope @object.collectible_user_id 
      sco.each { |tagging|
        # Looking for a member of the list that has a valid picture
        if tagging.entity.imgdata.present?
          @object.update_attribute :picture, tagging.entity.picref # Adopt the image as our own
          return @object.imgdata
        end
      }
    end
    img if img.present?
  end

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  # What types of tag are selectable for tagging the entity, i.e., pertain to the type of collectible we're talking about
  def eligible_tagtypes
    [ :Untyped, :Source, :Author, :Occasion, :Diet, :CulinaryTerm ]
  end

  # Specify the types of tag that get displayed individually on the card. :Misc is a special "grab bag" type for all eligible types not shown individually
  def individual_tagtypes
    [ :Misc, :Source, :Author, :List ]
  end

end
