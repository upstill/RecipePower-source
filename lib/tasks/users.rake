require 'net/http'
require 'json'
namespace :users do
  desc "Manage the user base"

  # Hit the mailgun API with our credentials to get JSON-formatted data on various queries
  # Return a Hash for the JSON data returned
  def mailgun_fetch path, qparams={}
    # Can specify an absolute path; otherwise, the path is relative to our domain
    path = '/v3/mg.recipepower.com/'+path unless path[0] == '/'
    uri = URI::HTTPS.build host: 'api.mailgun.net',
                           path: path,
                           query: URI.encode_www_form(qparams)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth("api", ENV['MAILGUN_API_KEY'])
    response = http.request(request)

    JSON.parse response.body
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
  # => set the address to invalid without affecting the subscription status
  task mail_bounces: :environment do
    if !bounces = mailgun_fetch('bounces', limit: 1000)['items']
      puts "Can't fetch bounces from Mailgun"
      return
    end
    process_users bounces.collect { |item| item['address'] }.compact, nil, false
    x=2
  end

  # A complaint is from a user who HAS a valid email address but who complained about getting mail
  # => email_valid is true, subscribed is false
  task mail_complaints: :environment do
    if !complaints = mailgun_fetch('complaints', limit: 1000)['items']
      puts "Can't fetch complaints from Mailgun"
      return
    end
    process_users complaints.collect { |item| item['address'] }.compact, false, true
  end

  # => email_valid is true, subscribed is false
  task mail_unsubscribes: :environment do
    if !unsubscribes = mailgun_fetch('unsubscribes', limit: 1000)['items']
      puts "Can't fetch unsubscribes from Mailgun"
      return
    end
    process_users unsubscribes.collect { |item| item['address'] }.compact, false, true
    x=2
  end

  task mail_events: :environment do
    response = mailgun_fetch 'events',
                  begin: (Time.now - 1.day).rfc2822,
                  ascending: 'yes',
                  limit: 3
  end

end
