class RpEvent < ActiveRecord::Base
  attr_accessible :on_mobile, :serve_count, :event_type, :user_id
  include Typeable

  typeable( :event_type,
            Untyped: ["Untyped", 0 ],
            Serve: ["Serve", 1],
            Followed_share_link: ["Followed_share_link", 2],
            Created_login_after_share: ["Created_login_after_share", 3],
            Went_to_recipe_after_share: ["Went_to_recipe_after_share", 4],
            Followed_invite_link: ["Followed_invite_link", 5],
            Created_login_after_invite: ["Created_login_after_invite", 6]
  )

  belongs_to :user

  # Register a serve to the user
  def self.log_serve uid=nil
    if uid ||= (current_user && current_user.id)
      # Get last serve for this user by date
      last_serve = RpEvent.where( :event_type => self.typenum(:Serve), :user_id => uid ).order( :modified_at ).last
      if last_serve && ((Time.now - last_serve.updated_at) < 10.minutes)
        last_serve.serve_count += 1
        last_serve.save
      else
        last_serve = RpEvent.create( user_id: uid, event_type: typenum(:Serve), :serve_count => 1)
      end
    end
    last_serve
  end

  # Return a hash of stats for the user
  def self.user_stats uid
    if last_visit = self.where( user_id: uid ).order(:created_at).last
      recent_visits = self.where( 'user_id = ? AND created_at > ?', uid, 1.month.ago ).count
      {last_visit: last_visit.created_at, recent_visits: recent_visits}
    else
      {}
    end

  end
end
