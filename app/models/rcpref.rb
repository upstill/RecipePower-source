require 'time_check'

# Rcpref is the join table between users and entities, denoting that a user has either collected
# the entity (:in_collection = true) or simply viewed it (:in_collection = false).
# Rcprefs also allow the user to leave a comment, and to declare it private from others.
class Rcpref < ActiveRecord::Base
  include Voteable

  belongs_to :entity, :polymorphic => true
  belongs_to :user
  counter_culture :user,
                  :column_name => Proc.new {|model| model.in_collection ? 'count_of_collecteds' : nil },
                  :column_names => {
                      ["rcprefs.in_collection = true"] => 'count_of_collecteds'
                  }
  # before_save :ensure_unique
  attr_accessible :comment, :entity_type, :entity_id, :user_id, :in_collection, :updated_at, :created_at, :private

  # When saving a "new" use, make sure it's unique
  def ensure_unique
    puts "Ensuring uniqueness of user #{self.user_id.to_s} to recipe #{self.entity_id.to_s}"
  end

  def uncollect
    self.in_collection = false
    save
  end

end
