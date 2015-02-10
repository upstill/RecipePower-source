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

  # Absorb the votes from another into self
  def absorb other
    my_voter_ids = self.voter_ids
    other.votes.each { |vote| vote.voter.vote(self, vote.up) unless my_voter_ids.include?(vote.user_id)  }
    super if defined? super
  end

end
