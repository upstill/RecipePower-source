require 'net/http'
require 'json'
namespace :users do
  desc "Manage the user base"

  # Make an HTTPS request over ssl to get a JSON response
  def https_request url_or_uri
    uri = url_or_uri.is_a?(String) ? URI(url_or_uri) : url_or_uri
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth("api", ENV['MAILGUN_API_KEY'])
    response = http.request(request)

    JSON.parse response.body
  end

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
  def process_users(addresses, subscribed=nil, valid=nil)
    puts "Processing #{addresses.count} users"
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

  # A bounce means a permanent failure. Mailgun won't send to previously-bounced addresses
  task mail_check: :environment do
    if !bounces = mailgun_fetch('bounces', limit: 1000)['items']
      puts "Can't fetch bounces from Mailgun"
      return
    end
    # puts "Bounces:"
    # puts bounces
    # => set the address to invalid without affecting the subscription status
    process_users bounces.collect { |item| item['address'] }.compact, nil, false

    if !complaints = mailgun_fetch('complaints', limit: 1000)['items']
      puts "Can't fetch complaints from Mailgun"
      return
    end
    # puts "Complaints:"
    # puts complaints
    # => email_valid is true, subscribed is false
    process_users complaints.collect { |item| item['address'] }.compact, false, true

    if !unsubscribes = mailgun_fetch('unsubscribes', limit: 1000)['items']
      puts "Can't fetch unsubscribes from Mailgun"
      return
    end
    # puts "Unsubscribes:"
    # puts bounces
    # => email_valid is true, subscribed is false
    process_users unsubscribes.collect { |item| item['address'] }.compact, false, true

    addrs = {}
    # Take each 'delivered' event as validation of the email address UNLESS it's otherwise invalid (as above)
    each_event(event: 'delivered') do |item|
      addrs[item['recipient']] = true
    end
    process_users(addrs.keys) do |user|
      user.update_attribute(:email_valid, true) if user.email_valid.nil?
    end

    # Any addresses that still have nil email_valid?
  end

  def each_event qparams={}
    qparams = {
        begin: Time.now.rfc2822,
        ascending: 'no',
        limit: 100 # end: (Time.now - 1.day).rfc2822 #
    }.merge qparams
    response = mailgun_fetch 'events', qparams
    while response && response['items'].present? do
      response['items'].each do |item|
        item['datetime'] = Time.at(item['timestamp'].to_i).to_datetime
        yield item
      end
      response = response['paging'] && response['paging']['next'] && https_request(response['paging']['next'])
    end
  end

  task mail_events: :environment do
    addrs = {}
    msgs = { 'yahoo' => {}, 'gmail' => {}, 'misc' => {} }
    bogus_addresses = []
    temporarily_deferred = []
    each_event(severity: 'permanent', event: 'failed') do |item|
      recipient, domain, errmsg = item['recipient'], item['recipient-domain'], (item['delivery-status']['message'] || '(no errmsg)')
      bogus_addresses << recipient
      errkey =
          if domain.present? && domain.match(/(yahoo|aol|ymail)\./)
            temporarily_deferred << recipient if errmsg.match /4\.7\.0/
            'yahoo'
          elsif domain.present? && domain.match('gmail')
            errmsg.sub! /(NoSuchUser|OverQuotaTemp|OverQuotaPerm|DisabledUser).* - gsmtp/, ' <id> gsmtp'
            'gmail'
          else
            match = errmsg.strip.match /^([\d\.]*)/
            (match && match[1].if_present) || ('No MX' if errmsg.match('No MX') ) || 'misc'
          end
      errmsg.sub! recipient, '..$recipient..'
      errmsg.sub! 'yahoo.com', 'yahoo(dot)com'
      errmsg.sub!(domain, '..$domain..') if domain.present?
      errmsg.sub! /mta\d*\.mail\.\w\w\w/, '<mtamsg>'
      ((msgs[errkey] ||= {})[errmsg] ||= []) << item
      (addrs[recipient] ||= []) << item
    end
    x=2
    bogus_addresses = bogus_addresses.uniq
    temporarily_deferred = temporarily_deferred.uniq
    process_users bogus_addresses-temporarily_deferred, nil, false
    User.where(email: temporarily_deferred).not(email_valid: nil).each { |u| u.update_attribute :email_valid, nil }
    msgs.each { |errkey, items|
      puts "\n=============== #{errkey} =============== "
      puts items.collect { |item|
        "\t#{item['recipient']} at domain '#{item['recipient-domain']}'"
      }.join "\n---------------\n"
    }
  end
end
