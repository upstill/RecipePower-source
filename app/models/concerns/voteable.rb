module Voteable
  extend ActiveSupport::Concern

  included do
    has_many :votes, :as => :entity, :dependent => :destroy
    has_many :voters, :through => :votes, :class_name => "User"
  end

  def upvotes
    votes.where(up: true).count
  end

  def downvotes
    votes.where(up: false).count
  end

  def nvotes
    votes.count
  end

  def pct_positive
    upvotes/nvotes if nvotes > 0
  end

  def vote up, user
    Vote.vote self, up, user
  end

end
