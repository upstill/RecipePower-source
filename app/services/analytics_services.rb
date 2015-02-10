class AnalyticsServices
  attr_accessor :name, :begin_time, :end_time, :data

  def divide(a, b)
    (b > 0) ? a.to_f/b : "NaN"
  end

  # An array of supported data (symbols and their labels within a column of data)
  @@analysands =
  {
    :active_users => "# Active Users",
    :sessions_per_active_user => "Sessions/Active User",
    :dropouts => "Dropouts",
    :new_users => "Total New Users",
    :accepted_invitations => "Invitations Resulting in Signup",
    :cold_signups => "Cold Signups",
    :net_new_users => "Net New Users (New Users - Dropouts)",
    :viral_coefficient => "Viral Coefficient",
    :invitations_issued => "Invitations Issued",
    :invitations_clicked => "Invitations Clicked",
    :invitation_click_rate => "Invitation Click Rate (clicks/invitation)",
    :invitations_converted => "Invitations Converted",
    :invitation_conversion_rate => "Invitation Conversion Rate",
    :invitations_diverted => "Invitations Diverted",
    :invitation_response_conversion_rate => "Invitation Response Conversion Rate (signups/clickthrough",
    :shares_issued => "Shares Issued",
    :shares_clicked => "Shares Clicked",
    :share_click_rate => "Share Click Rate (clicks/share)",
    :shares_converted => "Shares Converted",
    :share_conversion_rate => "Share Conversion Rate",
    :shares_diverted => "Shares Diverted",
    :share_response_conversion_rate => "Share Response Conversion Rate (signups/clickthrough",
  }

  def initialize interval, prior_interval = nil
    self.name, self.begin_time, self.end_time, prior_begin = [
        interval[:name], interval[:begin_time], interval[:end_time], (prior_interval[:begin_time] if prior_interval)
    ]
    @data = {}

    # Calculate # active users and sessions per active user
    sessions = RpEvent.events_of_type_during(:session, begin_time, end_time).map(&:subject_id)
    active_user_ids = sessions.uniq
    @data[:sessions_per_active_user] = divide sessions.count, (@data[:active_users] = active_user_ids.count)

    # Get # of dropouts in prior interval
    @data[:dropouts] = if prior_begin
                         prior_active = RpEvent.events_of_type_during(:session, prior_begin, begin_time).map(&:subject_id).uniq
                         (prior_active - active_user_ids).count
                       else
                         "n/a"
                       end

    # Get new successful invitees (signed up in interval)
    @data[:accepted_invitations] = RpEvent.events_of_type_during(:invitation_accepted, begin_time, end_time).count
    @data[:cold_signups] = User.where('invitation_token IS NULL AND created_at > ? AND created_at <= ?', begin_time, end_time).count

    # Get new users of all kinds (accepted invitations + uninvited signups)
    @data[:new_users] = @data[:accepted_invitations] + @data[:cold_signups]

    @data[:net_new_users] = @data[:dropouts].class==Fixnum ? (@data[:new_users] - @data[:dropouts]) : "n/a"

    @data[:viral_coefficient] = @data[:accepted_invitations].to_f / User.all.count

    @data[:invitations_issued] = RpEvent.events_of_type_during(:invitation_sent, begin_time, end_time).count
    @data[:invitations_clicked] = RpEvent.events_of_type_during(:invitation_responded, begin_time, end_time).count
    @data[:invitations_converted] = RpEvent.events_of_type_during(:invitation_accepted, begin_time, end_time).count
    @data[:invitations_diverted] = RpEvent.events_of_type_during(:invitation_diverted, begin_time, end_time).count

    @data[:invitation_conversion_rate] = divide @data[:invitations_converted], @data[:invitations_issued]
    @data[:invitation_click_rate] = divide @data[:invitations_clicked], @data[:invitations_issued]
    @data[:invitation_response_conversion_rate] = divide @data[:invitations_converted], @data[:invitations_clicked]

    shares_issued_by_id = RpEvent.events_of_type_during(:invitation_sent, begin_time, end_time).where('object_id IS NOT NULL').map(&:id)
    @data[:shares_issued] = shares_issued_by_id.count
    @data[:shares_clicked] = RpEvent.events_of_type_during(:invitation_responded, begin_time, end_time).where(object_type: "RpEvent", object_id: shares_issued_by_id).count
    @data[:shares_converted] = RpEvent.events_of_type_during(:invitation_accepted, begin_time, end_time).where(object_type: "RpEvent", object_id: shares_issued_by_id).count
    @data[:shares_diverted] = RpEvent.events_of_type_during(:invitation_diverted, begin_time, end_time).where(object_type: "RpEvent", object_id: shares_issued_by_id).count

    @data[:share_conversion_rate] = divide @data[:shares_converted], @data[:shares_issued]
    @data[:share_click_rate] = divide @data[:shares_clicked], @data[:shares_issued]
    @data[:share_response_conversion_rate] = divide @data[:shares_converted], @data[:shares_clicked]
  end

  # Generate intervals (month is 0-based)
  def self.gen_intervals num, dt, intvl, beforehand
    intvl = intvl.to_sym
    this = dt.advance intvl => -num+1
    out = []
    if beforehand
      that = this
      this = DateTime.new(2010)
      num += 1
    else
      that = this.advance intvl => 1
    end
    num.times do |i|
      name = (intvl == :months ? "" : this.day.to_s+"/")+this.month.to_s+"/"+this.year.to_s.sub(/^\d\d/, '')
      out << {name: name, begin_time: this, end_time: that}
      this = that
      that = this.advance intvl => 1
    end
    out[0][:name] = ("< "+out[1][:name]) if beforehand
    out
  end

# Generate a new instance for each interval as stipulated
  def self.generate period=:monthly, num_cols=3, beforehand=true, all_time=true
    # Generate the intervals
    now = Time.now # 2013-11-11 14:12:45 +1300
    case period = period.to_sym
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
    all_time = {name: "All Time", begin_time: DateTime.new(2011), end_time: DateTime.new(Time.now.year+1)} if all_time
    beforehand = false unless num_cols > 0
    intervals = []
    prior = nil
    self.gen_intervals(num_cols, start, intvl, beforehand).each do |interval|
      intervals << (block_given? ? yield(interval, prior) : interval.inspect)
      prior = interval
    end
    # intervals[0].name = "< "+intervals[1].name if beforehand
    intervals << (block_given? ? yield(all_time, nil) : all_time.inspect) if all_time
    intervals
  end

  # Compile analytics over a series of intervals and return an array of results, one for
  # each interval. Each column is a has of results.
  def self.analyze length=:monthly, num_cols=3, beforehand=true, all_time=true
    prior_begin = nil
    self.generate(length, num_cols, beforehand, all_time) do |interval, prior|
      self.new interval, prior
    end
  end

  def self.tabulate length=:monthly, num_cols=3, beforehand=true, all_time=true
    columns = self.analyze length, num_cols, beforehand, all_time
    rows = @@analysands.collect do |key, value|
      row = {name: value}
      columns.each do |column|
        row[column.name] = column.data[key]
      end
      row
    end

    headers = {name: ""}
    columns.each { |col| headers[col.name] = col.name }
    TablePresenter.new "Aggregate User Data", rows, headers
  end

end
