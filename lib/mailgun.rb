
# Hit the mailgun API with our credentials to get JSON-formatted data on various queries
# Return a Hash for the JSON data returned
def mailgun_fetch path, qparams={}
  # Can specify an absolute path; otherwise, the path is relative to our domain
  path = '/v3/mg.recipepower.com/'+path unless path[0] == '/'
  uri = URI::HTTPS.build host: 'api.mailgun.net',
                         path: path,
                         query: URI.encode_www_form(qparams)
  https_request uri
end

# Take semantic action for a collection of users defined by email addresses
def mg_process_users(addresses, subscribed=nil, valid=nil)
  User.where(email: addresses).each { |user|
    if block_given?
      yield user
    else
      user.subscribed = subscribed unless subscribed.nil?
      user.email_valid = valid unless valid.nil?
      user.save
    end
  }
end

# Query for (possibly paged) mailgun events denoted by qparams, calling the provided block for each one
def each_mailgun_event qparams={}, &block
  qparams = {
      begin: Time.now.rfc2822,
      ascending: 'no',
      limit: 100 # end: (Time.now - 1.day).rfc2822 #
  }.merge qparams
  response = mailgun_fetch 'events', qparams
  while response && response['items'].present? do
    response['items'].each do |item|
      item['datetime'] = Time.at(item['timestamp'].to_i).to_datetime
      block.call item
    end
    response = response['paging'] && response['paging']['next'] && https_request(response['paging']['next'])
  end
end

# Return the event items for a given email address
def mailgun_events_for(address)
  items = []
  each_mailgun_event(recipient: address) do |item|
    items << item
  end
  items
end

# Report on the extant permanent errors in the Mailgun logs, bucketing them into 'yahoo', 'gmail', error type and other
# Return a three-element array:
# [0]: a hash on message types, where each is a hash on email addresses whose values are lists of log items
# [1]: an array of addresses certifiably bogus
# [2]: an array of addresses that have "Temporarily Deferred" messages, i.e., they could be bogus or not
def mg_distill_errors
  msgs = { 'yahoo' => {}, 'gmail' => {}, 'misc' => {} }
  bogus_addresses = []
  temporarily_deferred = []
  each_mailgun_event(severity: 'permanent', event: 'failed') do |item|
    recipient, domain, errmsg = item['recipient'], item['recipient-domain'], (item['delivery-status']['message'].if_present || '(no errmsg)')
    bogus_addresses << recipient
    errmsg.sub! recipient, '..$recipient..'
    errkey =
        if domain.present? && domain.match(/(yahoo|aol|ymail)\./)
          errmsg.sub! 'yahoo.com', 'yahoo(dot)com'
          errmsg.sub! /^while reading response: short response: /, ''
          # puts "#{recipient}: #{errmsg}"
          temporarily_deferred << recipient if errmsg.match /4\.7\.0/
          # puts "\t=> #{temporarily_deferred.last}"
          'yahoo'
        elsif domain.present? && domain.match('gmail')
          errmsg.sub! /(NoSuchUser|OverQuotaTemp|OverQuotaPerm|DisabledUser).* - gsmtp/, ' <id> gsmtp'
          'gmail'
        else
          errmsg.sub! /\[[^\[]*.prod.protection.outlook.com\]/, '[$mailbox.prod.protection.outlook.com]'
          match = errmsg.strip.match /^([\d\.]*)/
          (match && match[1].if_present) || ('No MX' if errmsg.match('No MX') ) || 'misc'
        end
    errmsg.sub!(domain, '..$domain..') if domain.present?
    errmsg.sub! /mta\d*\.mail\.\w\w\w/, '<mtamsg>'
    ((msgs[errkey] ||= {})[errmsg] ||= []) << item
  end
  [ msgs, bogus_addresses.uniq, temporarily_deferred.uniq ]
end
