class AnalyticsServices
  attr_accessor :name, :time_range, :data

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

  def initialize name, interval, prior_interval = nil
    self.name, self.time_range = name, interval
    @data = {}

    # Calculate # active users and sessions per active user
    # time_scope = InvitationSentEvent.where created_at: time_range
    session_uids = LoginEvent.during(time_range).pluck :who_id
    active_user_ids = session_uids.uniq
    @data[:sessions_per_active_user] = divide session_uids.count, (@data[:active_users] = active_user_ids.count)

    # Get # of dropouts in prior interval
    @data[:dropouts] = if prior_interval
                         prior_active = LoginEvent.during((prior_interval.min)..time_range.min).pluck(:who_id).uniq
                         (prior_active - active_user_ids).count
                       else
                         "n/a"
                       end

    # Get new successful invitees (signed up in interval)
    @data[:accepted_invitations] = InvitationAcceptedEvent.during(time_range).count
    @data[:cold_signups] = User.where(invitation_token:nil, created_at: time_range).count

    # Get new users of all kinds (accepted invitations + uninvited signups)
    @data[:new_users] = @data[:accepted_invitations] + @data[:cold_signups]

    @data[:net_new_users] = @data[:dropouts].class==Fixnum ? (@data[:new_users] - @data[:dropouts]) : "n/a"

    @data[:viral_coefficient] = @data[:accepted_invitations].to_f / User.all.count

    @data[:invitations_issued] = InvitationSentEvent.during(time_range).count
    @data[:invitations_clicked] = InvitationRespondedEvent.during(time_range).count
    @data[:invitations_converted] = InvitationAcceptedEvent.during(time_range).count
    @data[:invitations_diverted] = InvitationDivertedEvent.during(time_range).count

    @data[:invitation_conversion_rate] = divide @data[:invitations_converted], @data[:invitations_issued]
    @data[:invitation_click_rate] = divide @data[:invitations_clicked], @data[:invitations_issued]
    @data[:invitation_response_conversion_rate] = divide @data[:invitations_converted], @data[:invitations_clicked]

    # A Share is an invitation whose indirect object is an entity
    shares_issued_by_id = InvitationSentEvent.during(time_range).where.not(invitation_event_id: nil).pluck :id
    @data[:shares_issued] = shares_issued_by_id.count
    @data[:shares_clicked] = InvitationRespondedEvent.during(time_range).where(invitation_event_id: shares_issued_by_id).count
    @data[:shares_converted] = InvitationAcceptedEvent.during(time_range).where(invitation_event_id: shares_issued_by_id).count
    @data[:shares_diverted] = InvitationDivertedEvent.during(time_range).where(invitation_event_id: shares_issued_by_id).count

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
      out << {name: name, time_range: this..that }
      this = that
      that = this.advance intvl => 1
    end
    out[0][:name] = ("< "+out[1][:name]) if beforehand
    out
  end

# Generate a new instance for each interval as stipulated
  def self.generate period=:monthly, num_cols=3, beforehand=true
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
    all_time = {
        name: "All Time",
        time_range: (6.years.ago)..Time.now,
    }
    beforehand = false unless num_cols > 0
    intervals = []
    prior_interval = nil
    self.gen_intervals(num_cols, start, intvl, beforehand).each do |interval|
      intervals << (block_given? ? yield(interval[:name], interval[:time_range], prior_interval) : interval.inspect)
      prior_interval = interval[:time_range]
    end
    # intervals[0].name = "< "+intervals[1].name if beforehand
    intervals << (block_given? ? yield('All Time', (6.years.ago)..Time.now, nil) : all_time.inspect)
    intervals
  end

  # Compile analytics over a series of intervals and return an array of results, one for
  # each interval. Each column is a has of results.
  def self.analyze length=:monthly, num_cols=3, beforehand=true
    self.generate(length, num_cols, beforehand) do |name, interval, prior_interval|
      self.new name, interval, prior_interval
    end
  end

  def self.tabulate length=:monthly, num_cols=3, beforehand=true
    columns = self.analyze length, num_cols, beforehand
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
