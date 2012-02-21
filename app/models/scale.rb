class Scale < ActiveRecord::Base
	has_many :ratings
	has_many :recipes, :through=>:ratings
	attr_accessible :id, :minlabel, :maxlabel, :name #, :minval, :maxval

    def value_as_text(val)
        s = ["super ", "very ", "fairly ", "", "fairly ", "very ", "super "][val+3]
        if (val < 0)
           s + self.minlabel.downcase
        elsif(val > 0)
           s + self.maxlabel.downcase
        else 
           "middling " + self.name.downcase
        end
    end
end
