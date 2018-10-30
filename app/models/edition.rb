class Edition < ApplicationRecord
  include Backgroundable

  backgroundable :status
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
  validates :guest_type, inclusion: { in: %w(User Referent), message: "%{value} is not a valid guest" }

  before_save do |ed|
    if ed.published_changed? && ed.published # PUBLISH! Queue up mailer job
      ed.published_at ||= Time.now
    end
  end


  after_save do |ed|
    if ed.published && ed.published_at
      # Launch if virgin/relaunch if published_at has changed
      if ed.virgin? || (ed.dj && (ed.dj.run_at != ed.published_at))
        ed.bkg_launch true, run_at: ed.published_at
      end
    end
  end

  # The edition performs by mailing all subscribed users, one every 20 minutes (to conform to MailGun limitations)
  def perform
    self.number ||= (Edition.maximum(:number) || 0) + 1
    time = Time.now + 5.seconds
    User.where(subscribed: true).where("last_edition < #{number}").each { |u|
      u.bkg_launch true, run_at: time
      time = time + 4.minutes # 360/day per MailGun terms
    }
  end

  def banner
    "Newsletter " +
        (published ?
        "##{number}: #{published_at.strftime('%d %b, %Y')}" :
        'Draft')
  end
end
