class AnalyticsServices
  attr_accessor :name, :begin_time, :end_time, :prior_interval, :data

  def self.divide_by(a, b)
    (b > 0) ? a.to_f/b : "NaN"
  end

  def initialize name, begin_time, end_time, prior_interval = nil
    self.name, self.begin_time, self.end_time, self.prior_interval = [name, begin_time, end_time, prior_interval]
    @data = {}

    # Calculate # active users and sessions per active user
    sessions = RpEvent.events_of_type_during(:session, begin_time, end_time).map(&:source_id)
    active_user_ids = sessions.uniq
    @data[:sessions_per_active_user] = self.divide sessions.count, active_user_ids.count

    # Get # of dropouts in prior interval
    @data[:dropouts] = if prior_interval
                         prior_active = RpEvent.events_of_type_during(:session, prior.begin_time, prior.end_time).map(&:source_id).uniq
                         (prior_active - active_user_ids).count
                       else
                         "n/a"
                       end

    # Get new successful invitees (signed up in interval)
    @data[:accepted_invitations] = RpEvent.events_of_type_during(:invitation_accepted, begin_time, end_time).count
    @data[:cold_signups] = User.where('invitation_token == NULL AND created_at > ? AND created_at <= ?', begin_time, end_time).count

    # Get new users of all kinds (accepted invitations + uninvited signups)
    @data[:new_users] = @data[:accepted_invitations] + @data[:cold_signups]

    @data[:net_new_users] = @data[:new_users] - @data[:dropouts]

    @data[:viral_coefficient] = @data[:accepted_invitations].to_f / User.all.count

    @data[:invitations_issued] = RpEvent.events_of_type_during(:invitation_sent, begin_time, end_time).count
    @data[:invitations_clicked] = RpEvent.events_of_type_during(:invitation_responded, begin_time, end_time).count
    @data[:invitations_converted] = RpEvent.events_of_type_during(:invitation_accepted, begin_time, end_time).count
    @data[:invitations_diverted] = RpEvent.events_of_type_during(:invitation_diverted, begin_time, end_time).count

    @data[:invitation_conversion_rate] = self.divide @data[:invitations_converted], @data[:invitations_issued]
    @data[:invitation_click_rate] = self.divide @data[:invitations_clicked], @data[:invitations_issued]
    @data[:invitation_response_conversion_rate] = self.divide @data[:invitations_converted], @data[:invitations_clicked]

    shares_issued_by_id = RpEvent.events_of_type_during(:invitation_sent, begin_time, end_time).where('subject_id IS NOT NULL').map(&:id)
    @data[:shares_issued] = shares_issued_by_id.count
    @data[:shares_clicked] = RpEvent.events_of_type_during(:invitation_responded, begin_time, end_time).where(subject_type: "RpEvent", subject_id: shares_issued_by_id).count
    @data[:shares_converted] = RpEvent.events_of_type_during(:invitation_accepted, begin_time, end_time).where(subject_type: "RpEvent", subject_id: shares_issued_by_id).count
    @data[:shares_diverted] = RpEvent.events_of_type_during(:invitation_diverted, begin_time, end_time).where(subject_type: "RpEvent", subject_id: shares_issued_by_id).count

    @data[:share_conversion_rate] = self.divide @data[:shares_converted], @data[:shares_issued]
    @data[:share_click_rate] = self.divide @data[:shares_clicked], @data[:shares_issued]
    @data[:share_response_conversion_rate] = self.divide @data[:shares_converted], @data[:shares_clicked]
  end

  # Generate intervals (month is 0-based)
  def self.gen_intervals num, dt, intvl, length
    intvl = intvl.to_sym
    this = dt.advance intvl => (-length*(num-1))
    out = []
    i = 0
    while i < num
      that = this.advance intvl => length
      name = this.day.to_s+"/"+this.month.to_s+"/"+this.year.to_s
      name.sub(/\/.*\//, '') if intvl == :months
      out[i] = {name: name, begin_time: this, end_time: that}
      this = that
      i = i+1
    end
    out
  end

# Generate a new instance for each interval as stipulated
  def self.on_intervals length=:monthly, num_cols=5, all_time=true
    # Generate the intervals
    now = Time.now # 2013-11-11 14:12:45 +1300
    case length
      when :monthly
        start = DateTime.new now.year, now.month
        intvl = :months
      when :weekly
        start = DateTime.new now.year, now.month, now.day
        weekday = start.inspect.match(/^(...)/)[1]
        daysoff = %w{ Sun Mon Tue Wed Thu Fri Sat }.index(weekday)
        start = start.advance(:days => -daysoff)
        intvl = :weeks
    end
    all_time = {name: "All Time", begin_time: DateTime.new(2013), end_time: Time.now}
    prior = nil
    self.gen_intervals(num_cols, start, intvl, 1).collect { |interval|
      prior = self.new interval[:name], interval[:begin_time], interval[:end_time], prior
    } << self.new(all_time[:name], all_time[:begin_time], all_time[:end_time])
  end

end