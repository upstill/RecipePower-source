# require 'test/unit'
require 'test_helper'
class EventTest < ActiveSupport::TestCase
  fixtures :users

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    RpEvent.create
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  test "table exists" do
    assert RpEvent.first, "There is an event class and at least one record"
  end

  test "event is typeable" do
    u = users :thing1
    evt = LoginEvent.post u
    LoginEvent.mass_assignable_attributes.to_a.include? 'status'
    assert_equal 'LoginEvent', evt.type
    assert_equal u, evt.who
    assert LoginEvent.find_by(who: u)
  end

  test 'before and after and during work' do
    u = users :thing1
    evt = LoginEvent.post u
    assert_nil LoginEvent.after(Time.now + 1.day).first
    assert_equal evt, LoginEvent.after(Time.now - 1.day).first
    assert_nil LoginEvent.before(Time.now - 1.day).first
    assert_equal evt, LoginEvent.before(Time.now + 1.day).first
    assert_equal evt, LoginEvent.during((Time.now - 1.day)..(Time.now + 1.day)).first
  end

  test 'Invitation Sent' do
    inviter = users :thing1
    invitee = users :thing2
    invitee.invited_by_id = inviter.id

    ie = InvitationSentEvent.post inviter, invitee
    assert_equal inviter, ie.inviter
    assert_equal invitee, ie.invitee
    ie2 = InvitationSentEvent.find_by_invitee invitee
    assert_equal inviter, ie2.inviter
    assert_equal invitee, ie2.invitee
  end

  test 'Invitation Accepted' do
    inviter = users :thing1
    invitee = users :thing2
    invitee.invited_by_id = inviter.id

    ie = InvitationSentEvent.find_or_create_by inviter: inviter, invitee: invitee
    assert_equal inviter, ie.inviter
    assert_equal invitee, ie.invitee
    iae = InvitationAcceptedEvent.post invitee, ie
    assert_equal ie, iae.invitation_event
    assert_equal invitee, iae.invitee
  end

  test 'event triggers work' do
    inviter = users :thing1
    invitee = users :thing2
    invitee.invited_by_id = inviter.id

    data = InvitationSentEvent.event_trigger_data inviter, invitee
    ise = RpEvent.trigger_event data
    assert_equal InvitationSentEvent, ise.class
    assert_equal inviter, ise.inviter
    assert_equal invitee, ise.invitee
  end

end
