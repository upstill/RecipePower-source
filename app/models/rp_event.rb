class RpEvent < ActiveRecord::Base
  attr_accessible :on_mobile, :serve_count, :verb, :source_id, :subject_id, :target_id, :data

  serialize :data

  belongs_to :source, class_name: "User"
  belongs_to :subject, polymorphic: true
  belongs_to :target, polymorphic: true

  include Typeable

  typeable( :verb,
            Untyped: ["Untyped", 0 ],
            serve: ["Serve", 1],
            invitation_sent: ["Send Invitation", 2],
            invitation_responded: ["Respond to Invitation", 3],
            invitation_accepted: ["Accepted Invitation", 4],
            invitation_diverted: ["Invitation Diverted", 5]
     )

  belongs_to :user

  # Return a hash of stats for the user
  def self.user_stats user, interval
    if last_visit = self.last(:serve, user)
      recent_visits = self.where( 'verb = ? AND source_id = ? AND created_at > ?', typenum(:serve), user.id, interval ).count
      {last_visit: last_visit.created_at, recent_visits: recent_visits}
    else
      {}
    end
  end
  
  # Return the last event posted by the given user (if any) of a given type
  def self.last verb, who=nil
    rel = self.where(verb: self.typenum(verb))
    rel = rel.where(source_id: who.id) if who
    rel.order( :updated_at ).last
  end

private
  def self.assemble_attributes verb, source, subject, target
    h = { verb: typenum(verb) }
    h.merge!(source_id: source.id) if source
    h.merge!(subject_type: subject.class.to_s, subject_id: subject.id) if subject
    h.merge!(target_type: target.class.to_s, target_id: target.id) if target
    h
  end

  # post an event of the given type, avoiding duplicates
  def self.post verb, source, subject, target, data={}
    posted = self.where(self.assemble_attributes(verb, source, subject, target)).first_or_create
    if (posted.data != data)
      posted.data = data
      posted.save
    end
    posted
  end

  # Provide a structure for embedding a trigger in a URL for automatically firing an event upon a click
  def self.embed_trigger( verb, source, subject, target, data = nil )
    h = self.assemble_attributes(verb, source, subject, target)
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

  def self.events_of_type_during verb, begin_time, end_time
    RpEvent.where 'verb = ? AND created_at >= ? AND created_at < ?', typenum(verb), begin_time, end_time
  end
end
