class RpEvent < ActiveRecord::Base

  include Typeable

  typeable( :verb,
            Untyped: ["Untyped", 0 ],
            session: ["Session", 1],
            invitation_sent: ["Send Invitation", 2],
            invitation_responded: ["Respond to Invitation", 3],
            invitation_accepted: ["Accepted Invitation", 4],
            invitation_diverted: ["Invitation Diverted", 5]
  )

  attr_accessible :on_mobile, :serve_count, :subject_id, :object_id, :object2_id, :data

  serialize :data

  # belongs_to :source, class_name: "User"
  belongs_to :subject, polymorphic: true
  belongs_to :object, polymorphic: true
  belongs_to :object2, polymorphic: true
  has_many :event_notices
  has_many :users, :through => :event_notices

  belongs_to :user

  # Return a hash of aggregate_user_table for the user
  def self.user_stats user, interval
    if last_visit = self.last(:serve, user)
      recent_visits = self.where( 'verb = ? AND subject_id = ? AND created_at > ?', typenum(:serve), user.id, interval ).count
      {last_visit: last_visit.created_at, recent_visits: recent_visits}
    else
      {}
    end
  end

  # Return the last event posted by the given user (if any) of a given type
  def self.last verb, subject=nil
    rel = self.where(verb: self.typenum(verb))
    rel = rel.where(subject_id: subject.id) if subject
    rel.order( :updated_at ).last
  end

private
  def self.assemble_attributes subject, verb, object, object2
    h = { verb: typenum(verb) }
    h.merge!(subject_id: subject.id) if subject
    h.merge!(object_type: object.class.to_s, object_id: object.id) if object
    h.merge!(object2_type: object2.class.to_s, object2_id: object2.id) if object2
    h
  end

  # post an event of the given type, avoiding duplicates
  def self.post subject, verb, object, object2, data={}
    posted = self.where(self.assemble_attributes(subject, verb, object, object2)).first_or_create
    if (posted.data != data)
      posted.data = data
      posted.save
    end
    posted
  end

  # Provide a structure for embedding a trigger in a URL for automatically firing an event upon a click
  def self.embed_trigger( subject, verb, object, object2, data = nil )
    h = self.assemble_attributes(subject, verb, object, object2)
    h.merge!( data: data ) if data
    h
  end

  # In response to a trigger in a URL, post an event
  def self.fire_trigger params
    self.where(params).first_or_create
  end

  def self.events_during begin_time, end_time
    RpEvent.where 'created_at >= ? AND created_at < ?', begin_time, end_time
  end

  # Filter for events
  def self.events_of_type_during verb, begin_time, end_time
    RpEvent.where 'verb = ? AND created_at >= ? AND created_at < ?', typenum(verb), begin_time, end_time
  end

end
