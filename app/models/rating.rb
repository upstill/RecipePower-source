class Rating < ApplicationRecord
    belongs_to :recipe
    belongs_to :scale
    before_save :ensure_unique
    attr_reader :rating_name
    attr_reader :rating_minlabel
    attr_reader :rating_maxlabel
    attr_reader :rating_scale_id
    attr_reader :ratings_attributes

    def rating_attributes=(attrs)
	d { "Got Rating Attributes in Rating: "; attrs }
    end

    # When saving a "new" rating, make sure it's unique
    def ensure_unique
    end

    def rating_minlabel()
       return "<minlabel>" if self.scale_id.nil?
       scale = Scale.find(self.scale_id)
       scale.value_as_text(-2) # scale.minval)
    end

    def rating_maxlabel()
       return "<maxlabel>" if self.scale_id.nil?
       scale = Scale.find(self.scale_id)
       scale.value_as_text(2) # scale.maxval)
    end

    def rating_name()
       return "<scale>" if self.scale_id.nil?
       scale = Scale.find(self.scale_id)
       scale.name.nil? ? "<no name>" : scale.name
    end

    def rating_scale_id()
       self.scale_id.nil? ? 0 : self.scale_id
    end

    # Interpret the scale name of the rating in HTML
    def show_scale
       return "<nil scale id>" if self.scale_id.nil? 
       scale = Scale.find(self.scale_id)
       scale.name.nil? ? "<no name>" : scale.name
    end

    # Interpret the value of the rating 
    def value_as_text
	if(self.scale_id.nil? || self.scale_val.nil?) 
	   "<nil value>"
	else
           Scale.exists?(self.scale_id) ? 
	   Scale.find(self.scale_id).value_as_text(self.scale_val) :
	   "lost scale #{self.scale_id}"
        end
    end

    # Get a list of recipe keys matching the object's user_id, scale_id and scale_val
    def recipes
        ratings = Rating.where("scale_id = '#{self.scale_id}' AND scale_val = '#{self.scale_val}'")
	ratings.map { |r| r.recipe_id }
    end
end
