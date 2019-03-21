class Edition < ApplicationRecord
  include Backgroundable

  backgroundable :status
  require 'referent.rb'

=begin
  # attr_accessible :opening, :signoff,
                  :recipe_id, :recipe_before, :recipe_after,
                  :site_id, :site_before, :site_after,
                  :condiment_id, :condiment_type, :condiment_before, :condiment_after,
                  :list_id, :list_before, :list_after,
                  :guest_id, :guest_type, :guest_before, :guest_after,
                  :published, :published_at, :number
=end

  belongs_to :recipe
  belongs_to :site
  if Rails::VERSION::STRING[0].to_i < 5
    belongs_to :list
    belongs_to :condiment, polymorphic: true
    belongs_to :guest, polymorphic: true
  else
    belongs_to :list,
               optional: true
    belongs_to :condiment,
               polymorphic: true,
               optional: true
    belongs_to :guest,
               polymorphic: true,
               optional: true
  end
  validates :condiment_type, inclusion: { in: %w(List IngredientReferent), message: "%{value} is not a valid condiment" }
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
    time = Time.now
    User.where(subscribed: true).where("last_edition < #{number}").each { |u|
      time = time + 5.seconds
      u.bkg_launch true, run_at: time
    }
  end

  def banner
    "Newsletter " +
        (published ?
        "##{number}: #{published_at.strftime('%d %b, %Y')}" :
        'Draft')
  end
end
