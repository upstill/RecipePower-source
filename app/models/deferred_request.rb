class DeferredRequest < ApplicationRecord
  serialize :requests
  # attr_accessible :requests, :session_id
  self.primary_key = 'session_id'

  # Save the current request pending (presumably) a login, such that deferred_request and deferred_trigger
  # can reproduce it after login. Any of the current request parameters may be
  # overridden--or other data stored--by passing them in the elements hash
  def self.push sessid, dr
    logger.info "DeferredRequest for session #{sessid}: '#{dr}'"
    if sessid
      defreq = self.find_or_create_by session_id: sessid.to_s
      (defreq.requests << YAML::dump(dr)).uniq!
      defreq.save
      dr
    end
  end

  def self.pop sessid
    logger.info "DeferredRequest popping for session #{sessid}..."
    if sessid && (defreq = self.find_by(session_id: sessid.to_s))
      popped = defreq.requests.pop
      logger.info "...popped #{defreq.requests.count} requests"
      interp = popped ? YAML::load(popped) : "<nil>"
      logger.info "...the last of which is #{interp}"
      if defreq.requests.count > 0
        defreq.save
      else
        defreq.destroy
      end
      YAML::load(popped) if popped
    end
  end

  # Get, delete and return a request matching the specs, if any, or the topmost request otherwise
  def self.pull sessid, specs=nil
    logger.info "DeferredRequest pulling for session #{sessid} and specs #{specs}."
    if specs.blank?
      self.pop sessid
    elsif sessid &&
        (defreqs = self.find_by(session_id: sessid.to_s)) &&
        (ix = defreqs.requests.rindex { |req|
          req = YAML::load(req)
          specs.slice(:format, :mode).all? { |key, spec_val| req[key] == spec_val }
        })
      req = YAML::load(defreqs.requests.delete_at ix)
      logger.info "...found request #{req}"
      defreqs.requests.empty? ? defreqs.destroy : defreqs.save
      req
    end
  end

  # What's the next deferred request for this session?
  def self.pending sessid
    logger.info "DeferredRequest getting request pending for session #{sessid}"
    if defreq = self.find_by(session_id: sessid.to_s)
      if dr = defreq.requests[-1]
        logger.info "...found request #{YAML::load dr}."
        return YAML::load(dr)
      else
        logger.info "...no request found."
        defreq.destroy
      end
    end
    nil
  end

end
