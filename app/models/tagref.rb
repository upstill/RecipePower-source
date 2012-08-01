class Tagref < ActiveRecord::Base
    belongs_to :recipe
    belongs_to :tag
    before_save :ensure_unique
    after_save :notify_referents

    # When saving a "new" Tag, make sure it's unique
    def ensure_unique
puts "Ensuring uniqueness of tag #{self.tag_id.to_s} to recipe #{self.recipe_id.to_s}"
    end
    
    def notify_referents
        debugger
        self.tag.referents.each { |ref| ref.notice_resource self.recipe }
    end
        
end
