require 'net/http'
require 'json'

namespace :users do
  desc "Manage the user base"

  # Survey Mailgun statuses and events for changes to email validity
  task mail_check: :environment do

    addrs = {}
    # Take each 'delivered' event as validation of the email address
    each_mailgun_event(event: 'delivered') do |item|
      addrs[item['recipient']] = true
    end
    puts "#{addrs.count} users with delivered messages (=> email_valid = true)"
    mg_process_users(addrs.keys) do |user|
      user.update_attribute(:email_valid, true) if user.email_valid.nil?
    end

    msgs, bogus_addresses, temporarily_deferred = *mg_distill_errors()
    # Bogus addresses--but not temporarily deferred addresses--are invalid
    bogus_but_not_deferred = bogus_addresses-temporarily_deferred
    puts "#{bogus_but_not_deferred.count} users with permanent errors not deferred (=> email_valid = false)"
    mg_process_users bogus_but_not_deferred, nil, false
    
    puts "#{temporarily_deferred.count} users with temporarily deferred messages (=> email_valid false-> nil)"
    puts temporarily_deferred.join("\n\t")
    # Temporarily deferred addresses that were priorly false get nil email_valid
    User.where(email: temporarily_deferred, email_valid: false).each { |u| u.update_attribute :email_valid, nil }

    if !bounces = mailgun_fetch('bounces', limit: 1000)['items']
      puts "Can't fetch bounces from Mailgun"
      return
    end
    puts "#{bounces.count} bounced users (=> email_valid = false)"
    # => set the address to invalid without affecting the subscription status
    mg_process_users bounces.collect { |item| item['address'] }.compact, nil, false

    if !complaints = mailgun_fetch('complaints', limit: 1000)['items']
      puts "Can't fetch complaints from Mailgun"
      return
    end
    puts "#{complaints.count} users with complaints (=> subscribed = false; email_valid = true)"
    # => email_valid is true, subscribed is false
    mg_process_users complaints.collect { |item| item['address'] }.compact, false, true

    if !unsubscribes = mailgun_fetch('unsubscribes', limit: 1000)['items']
      puts "Can't fetch unsubscribes from Mailgun"
      return
    end
    puts "#{unsubscribes.count} unsubscribed users (=> subscribed = false; email_valid = true)"
    # => email_valid is true, subscribed is false
    mg_process_users unsubscribes.collect { |item| item['address'] }.compact, false, true
  end

  task mail_events: :environment do
    msgs, bogus_addresses, temporarily_deferred = *mg_distill_errors()
    msgs.each { |errkey, items|
      puts "\n=============== #{errkey} =============== "
      items.each do |errmsg, items_per_msg|
        puts errmsg
        items_by_date = items_per_msg.sort { |i1, i2| i1['datetime'] <=> i2['datetime'] }
        items_by_date.each do |item|
          puts "\t#{item['recipient']} of domain '#{item['recipient-domain']}' at #{item['datetime']}"
        end
      end
    }
  end

  # NOT WORKING: The idea here is to use the Mailgun API to validate email addresses, but the server
  # inevitably returns "Mailgun Magnificent API" as the response body
  task mail_validate: :environment do
    addrs = {
        deferred: 'cynsp2003@yahoo.com',
        delivered: 'cazstevemax@att.net',
        permanent_errors: 'jschlegel@pavetechinc.com',
        temporarily_deferred: 'nicscola@yahoo.com',
        bounced: 'couturetj@gmail.com',
        complaints: 'jcondron@comcast.net'
    }
    puts "Checking bad email:"
    result = mailgun_fetch "address/private/validate", address: 'wkeg&m'
    puts "\t#{u.email}: #{result.to_s}"
    sleep(3)
    puts "Checking users with unknown validity:"
    User.where(email_valid: nil).limit(3).each { |u|
      result = mailgun_fetch "address/private/validate", address: u.email, mailbox_verification: true
      puts "\t#{u.email}: #{result.to_s}"
      sleep(3)
      x=2
    }
    addrs.each { |key, addr|
      puts "Checking #{key}:"
      User.where(email: addr).each { |u|
        result = mailgun_fetch "address/private/validate", address: u.email, mailbox_verification: true
        puts "\t#{u.email}: #{result.to_s}"
        sleep(3)
        x=2
      }
    }
  end
end
