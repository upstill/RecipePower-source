class RpEvent < ActiveRecord::Base
  include Backgroundable
  backgroundable

  serialize :data

  # belongs_to :source, class_name: "User"
  belongs_to :subject, polymorphic: true
  belongs_to :direct_object, polymorphic: true
  belongs_to :indirect_object, polymorphic: true
  has_many :event_notices, class_name: 'ActivityNotification::Notification', as: :notifiable
  has_many :users, :through => :event_notices, source: :target, source_type: 'User'

  belongs_to :user

  attr_accessible :on_mobile, :serve_count, :subject_type, :subject_id, :direct_object_type, :indirect_object_type, :direct_object_id, :indirect_object_id, :data

  # Return a hash of aggregate_user_table for the user
  def self.user_stats user, interval
    serve_scope = LoginEvent.where subject_id: user.id
    if last_visit = serve_scope.order(:updated_at).last # self.last(:serve, user)
      {
          last_visit: last_visit.created_at,
          recent_visits: serve_scope.where( created_at: interval ).count
      }
    else
      {}
    end
  end

  # post an event of the given type, avoiding duplicates
  def self.post subject, direct_object=nil, indirect_object=nil, data={}
    if direct_object.is_a? Hash
      data, direct_object = direct_object, nil
    elsif indirect_object.is_a? Hash
      data, indirect_object = indirect_object, nil
    end
    args = self.assemble_attributes(subject, direct_object, indirect_object)
    posted = self.create_with(data: data).where(args).first_or_create
    if (posted.data != data)
      posted.data = data
      posted.save
    end
    posted
  end

  # Provide a structure for embedding a trigger in a URL for automatically firing an event upon a click
  def self.event_trigger_data( subject, direct_object=nil, indirect_object=nil, data = {} )
    h = self.assemble_attributes subject, direct_object, indirect_object
    h.merge!( data: data ) if data.present?
    h
  end

  # In response to a trigger in a URL, post an event
  def self.trigger_event params
    klass = params[:type].present? ? params.delete(:type).constantize : self
    klass.find_or_create_by params
  end

  def self.during timerange
    self.where created_at: timerange
  end

  # Events occuring before the given time
  def self.before time
    self.where 'created_at < :time', :time => time
  end

  # Events occuring after the given time
  def self.after time
    self.where 'created_at > :time', :time => time
  end

  # The target user of the notification responds to the event. Do something...
  def act notification, options={}
    # ...or nothing
  end

  def expression target
    subj_name = user_reference subject, target
    do_name = user_reference direct_object, target, true
    io_name = (indirect_object.name if indirect_object)
    if block_given?
      yield subj_name, verb, do_name, io_name
    else
      sentence subj_name, verb, do_name, io_name
    end
  end

  def sentence *parts
    parts.compact.join(' ').capitalize
  end

  # Override the verb for a coherent expression
  def verb
    '<your verb here>'
  end

  # How to name a user, substituting 'you' when the viewer and the user are the same
  def user_reference user, target, possessive = false
    if user
      if possessive
        user.id == target.id ? 'your' : (user.name+"'s")
      else
        user.id == target.id ? 'you' : user.name
      end
    else
      possessive ? 'your' : 'you'
    end
  end

  private
  def self.assemble_attributes subject, direct_object = nil, indirect_object = nil
    attrs = {
        type: self.to_s,
        subject_type: subject.class.to_s,
        subject_id: subject.id,
    }
    if direct_object
      attrs[:direct_object_type] = direct_object.class.to_s
      attrs[:direct_object_id] = direct_object.id
      if indirect_object
        attrs[:indirect_object_type] = indirect_object.class.to_s
        attrs[:indirect_object_id] = indirect_object.id
      end
    end
    attrs
  end

end

## And now, one subclass for each verb (type)

# <User> logged in
class LoginEvent < RpEvent
  alias_attribute :who, :subject
  attr_accessible :who

  # Login events accumulate for a given user
  def self.post who
    self.create who: who
  end
end

# <User> listed <Entity> [in] <Treasury>
class ListedEvent < RpEvent
end

# <User> collected <Entity>
class CollectedEvent < RpEvent
end

# <User> discovered <Site>
class DiscoveredEvent < RpEvent
end

# <Feed> posted <FeedEntry>
class PostedEvent < RpEvent
end

# <User> invited <User> [with <Shared Entity>]
class InvitationSentEvent < RpEvent

  alias_attribute :inviter, :subject
  alias_attribute :invitee, :direct_object
  alias_attribute :shared, :indirect_object
  attr_accessible :inviter, :invitee, :shared

  def self.post inviter, invitee, shared, raw_invitation_token
    super inviter, invitee, shared, raw_invitation_token: raw_invitation_token
  end

  acts_as_notifiable :users,
                     targets: ->(evt, key) {  [evt.invitee] },
                     notifier: ->(evt, key) { evt.invitee },
                     # notifiable_path: :share_path,
                     email_allowed: true,
                     # Set true to :tracked option to generate automatic tracked notifications.
                     # It adds required callbacks to generate notifications for creation and update of the notifiable model.
                     tracked: { only: [:create] }

  def self.find_by_invitee invitee
    # invitation_event = InvitationSentEvent.find_by_inviter_id resource.invited_by_id, invitee: resource
    self.find_by direct_object: invitee, subject_type: 'User', subject_id: invitee.invited_by_id
  end

  def expression target
    subject = user_reference(inviter, target)
    verb = 'invited'
    object = user_reference(invitee, target)
    indirect_object = (shared.name if shared)
    if block_given?
      yield subject, verb, object, indirect_object
    else
      complete_sentence subject, verb, object, indirect_object
    end
  end

  def complete_sentence subject, verb, object, indirect_object
    "#{subject} #{verb} #{object} to join RecipePower".html_safe
  end

  def verb
    'invited'
  end

end

# <User> responded to invitation <InvitationSentEvent>
class InvitationResponseEvent < RpEvent
  alias_attribute :invitee, :subject
  alias_attribute :inviter, :direct_object
  alias_attribute :invitation_event, :indirect_object
  attr_accessible :inviter, :invitee, :invitation_event

  acts_as_notifiable :users,
                     targets: ->(evt, key) {
                       case key.sub(/^.*\./, '')
                         when 'create'
                           [evt.inviter]
                         when 'welcome'
                           [evt.invitee]
                       end
                     },
                     notifier: ->(evt, key) {
                       evt.invitee
                     },
                     # notifiable_path: :share_path,
                     email_allowed: true,
                     # Set true to :tracked option to generate automatic tracked notifications.
                     # It adds required callbacks to generate notifications for creation and update of the notifiable model.
                     tracked: {only: [:create] }

end

class InvitationRespondedEvent < InvitationResponseEvent
end

# <User> accepted invitation <InvitationSentEvent>
class InvitationAcceptedEvent < InvitationResponseEvent
end

# <User> diverted invitation <InvitationSentEvent>
class InvitationDivertedEvent < InvitationResponseEvent
end

# <User> shared <Entity> [with] <User>
class SharedEvent < RpEvent
  alias_attribute :sharer, :subject
  alias_attribute :shared, :direct_object
  alias_attribute :sharee, :indirect_object
  attr_accessible :sharer, :shared, :sharee

  acts_as_notifiable :users,
                     targets: ->(evt, key) {  [evt.sharee] },
                     notifier: ->(evt, key) {  evt.sharer },
                     # notifiable_path: :share_path,
                     email_allowed: true,
                     # Set true to :tracked option to generate automatic tracked notifications.
                     # It adds required callbacks to generate notifications for creation and update of the notifiable model.
                     tracked: { only: [:create] }

  def share_path
    polymorphic_path shared
  end

  # Act on a Shared event by adding the entity to the collection of the user shared with
  # Return a string reporting on the action
  def act notification, options={}
    sharee.collect shared
    I18n.t 'notification.user.shared_event.act', shared: shared.decorate.title
  end

end

# <User> accepted <Entity> [from] <User>
# Accepted a share
class AcceptedEvent < RpEvent
end

# <User> published <List>
# Published new list
class PublishedEvent < RpEvent
end

# <User> touted <Entity>
# Touted an entity
class ToutedEvent < RpEvent
end
