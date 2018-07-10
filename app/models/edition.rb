class Edition < ActiveRecord::Base
  require 'referent.rb'

  attr_accessible :opening, :signoff,
                  :recipe_id, :recipe_before, :recipe_after,
                  :site_id, :site_before, :site_after,
                  :condiment_id, :condiment_type, :condiment_before, :condiment_after,
                  :list_id, :list_before, :list_after,
                  :guest_id, :guest_type, :guest_before, :guest_after,
                  :published, :published_at, :number
  belongs_to :recipe
  belongs_to :site
  belongs_to :list
  belongs_to :condiment, polymorphic: true
  validates :condiment_type, inclusion: { in: %w(List IngredientReferent), message: "%{value} is not a valid condiment" }
  belongs_to :guest, polymorphic: true
  validates :guest_type, inclusion: { in: %w(User AuthorReferent), message: "%{value} is not a valid guest" }

  before_save do |ed|
    if ed.published_changed? && ed.published
      ed.published_at = Time.now
      ed.number = (Edition.maximum(:number) || 0) + 1
    end
  end

  def banner
    "RecipePower Newsletter " +
        (published ?
        "##{number} #{published_at.strftime('%d %b, %Y')}" :
        'Draft')
  end
end
