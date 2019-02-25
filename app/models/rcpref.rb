require 'time_check'

# Rcpref is the join table between users and entities, denoting that a user has either collected
# the entity (:in_collection = true) or simply viewed it (:in_collection = false).
# Rcprefs also allow the user to leave a comment, and to declare it private from others.
class Rcpref < ApplicationRecord
  include Voteable

  belongs_to :entity, polymorphic: true
  belongs_to :user
  counter_culture :user,
                  :column_name => Proc.new {|model| model.in_collection ? 'count_of_collecteds' : nil },
                  :column_names => {
                      ["rcprefs.in_collection = true"] => 'count_of_collecteds'
                  }
  # Scope the user pointer for a specific user (like the current user)
  scope :toucher_pointer, -> (id) { where(user_id: id) }
  # Scope to fetch rcprefs for a given user and (possibly different) user
  scope :for_user, -> (userid, viewerid=userid, collected_only = true) {
    constraints = {  user_id: userid }
    constraints[:in_collection] = true if collected_only
    constraints[:private] = false if userid != viewerid
    where constraints
  }
  scope :matching_comment, -> (matchstr) {
    where('"rcprefs"."comment" ILIKE ?', "%#{matchstr}%")
  }
  # Filters Rcprefs for a collection of entity types
  scope :for_entities, -> (*entity_types) {

  }
  # Filters Rcprefs by entity types, excluding those given
  scope :except_entities, -> (*entity_types) {

  }
  # before_save :ensure_unique
  # attr_accessible :comment, :entity_type, :entity_id, :user_id, :in_collection, :updated_at, :created_at, :private

  # Establish belongs_to relations for all the known Collectible classes, mainly for use in joins
  # TODO: Smell! We're enumerating a relation for every collectible type. This really should be
  # declared in the Collectible module by modifying each class. But how?
  belongs_to :feeds, -> { where '"rcprefs"."entity_type" = \'Feed\'' }, foreign_key: 'entity_id', class_name: 'Feed'
  belongs_to :feed_entries, -> { where '"rcprefs"."entity_type" = \'FeedEntry\'' }, foreign_key: 'entity_id', class_name: 'FeedEntry'
  belongs_to :recipes, -> { where '"rcprefs"."entity_type" = \'Recipe\'' }, foreign_key: 'entity_id', class_name: 'Recipe'
  belongs_to :sites, -> { where '"rcprefs"."entity_type" = \'Site\'' }, foreign_key: 'entity_id', class_name: 'Site'
  belongs_to :lists, -> { where '"rcprefs"."entity_type" = \'List\'' }, foreign_key: 'entity_id', class_name: 'List'
  belongs_to :products, -> { where '"rcprefs"."entity_type" = \'Product\'' }, foreign_key: 'entity_id', class_name: 'Product'
  belongs_to :users, -> { where '"rcprefs"."entity_type" = \'User\'' }, foreign_key: 'entity_id', class_name: 'User'

  # When saving a "new" use, make sure it's unique
  def ensure_unique
  end

=begin
  def uncollect
    self.in_collection = false
    save
  end
=end

  # Ensure that the ref is properly registered with both the user's and the entity's associations
  def ensconce
    user.update_associations self
    entity.update_associations self
  end

  # We add functionality to catch a newly-collected ref and peg the created_at date to now
  def save options={}
    if created_at && in_collection && in_collection_changed?
      # We use the created_at time as "time of collection"
      self.created_at = self.updated_at = Time.now
      Rcpref.record_timestamps = false
      result = super
      Rcpref.record_timestamps = true
      result
    else
      super
    end
  end

end
