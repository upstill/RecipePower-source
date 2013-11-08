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
    rel = self.where( :verb => self.typenum(verb) )
    rel = rel.where( :source_id => who.id ) if who
    rel.order( :updated_at ).last
  end

  # post an event of the given type
  def self.post verb, source, subject, target, data={}
    evt = self.new verb: typenum(verb)
    evt.source = source
    evt.subject = subject
    evt.target = target
    evt.data = data
    evt.save
    evt
  end
end
