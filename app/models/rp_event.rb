class RpEvent < ActiveRecord::Base

=begin

  include Typeable

  typeable( :verb,
            Untyped: ["Untyped", 0 ],
            session: ["Session", 1],
            invitation_sent: ["Send Invitation", 2],
            invitation_responded: ["Respond to Invitation", 3],
            invitation_accepted: ["Accepted Invitation", 4],
            invitation_diverted: ["Invitation Diverted", 5]
  )
=end

  attr_accessible :verb
  enum :verb => [
           :untyped,
           :session,
           :invitation_sent,
           :invitation_responded,
           :invitation_accepted,
           :invitation_diverted
       ]

  attr_accessible :on_mobile, :serve_count, :subject_id, :direct_object_id, :indirect_object_id, :data

  serialize :data

  # belongs_to :source, class_name: "User"
  belongs_to :subject, polymorphic: true
  belongs_to :direct_object, polymorphic: true
  belongs_to :indirect_object, polymorphic: true
  has_many :event_notices
  has_many :users, :through => :event_notices

  belongs_to :user

  # Return a hash of aggregate_user_table for the user
  def self.user_stats user, interval
    serve_scope = RpEvent.session.where subject_id: user.id
    if last_visit = serve_scope.order(:updated_at).last # self.last(:serve, user)
      {
          last_visit: last_visit.created_at,
          recent_visits: serve_scope.where( created_at: interval ).count
      }
    else
      {}
    end
  end

private
  def self.assemble_attributes subject, verb, direct_object, indirect_object
    re = RpEvent.new  verb: verb,
                      subject: subject,
                      direct_object: direct_object,
                      indirect_object: indirect_object
    re.attributes.slice(:verb,
                        :subject_id,
                        :direct_object_type, :direct_object_id,
                        :indirect_object_type, :indirect_object_id).compact
=begin
    h = { verb: verb }
    h.merge!(subject_id: subject.id) if subject
    h.merge!(direct_object_type: direct_object.class.to_s, direct_object_id: direct_object.id) if direct_object
    h.merge!(indirect_object_type: indirect_object.class.to_s, indirect_object_id: indirect_object.id) if indirect_object
    h
=end
  end

  # post an event of the given type, avoiding duplicates
  def self.post subject, verb, direct_object, indirect_object, data={}
    posted = self.where(self.assemble_attributes(subject, verb, direct_object, indirect_object)).first_or_create
    if (posted.data != data)
      posted.data = data
      posted.save
    end
    posted
  end

  # Provide a structure for embedding a trigger in a URL for automatically firing an event upon a click
  def self.event_trigger_data( subject, verb, direct_object, indirect_object, data = nil )
    h = self.assemble_attributes(subject, verb, direct_object, indirect_object)
    h.merge!( data: data ) if data
    h
  end

  # In response to a trigger in a URL, post an event
  def self.trigger_event params
    self.where(params).first_or_create
  end

end
