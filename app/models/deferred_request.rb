class DeferredRequest < ActiveRecord::Base
  serialize :requests
  attr_accessible :requests, :session_id
  self.primary_key = 'session_id'

  # Save the current request pending (presumably) a login, such that deferred_request and deferred_trigger
  # can reproduce it after login. Any of the current request parameters may be
  # overridden--or other data stored--by passing them in the elements hash
  def self.push sessid, dr
    defreq = self.find_or_create_by session_id: sessid
    (defreq.requests << YAML::dump(dr)).uniq!
    defreq.save
    dr
  end

  def self.pop sessid
    if defreq = self.find_by(session_id: sessid)
      popped = defreq.requests.pop
      if defreq.requests.count > 0
        defreq.save
      else
        defreq.destroy
      end
      YAML::load(popped) if popped
    end
  end

  # What's the next deferred request for this session?
  def self.pending sessid
    if defreq = self.find_by(session_id: sessid)
      if dr = defreq.requests[-1]
        return YAML::load(dr)
      else
        defreq.destroy
      end
    end
    nil
  end

end
