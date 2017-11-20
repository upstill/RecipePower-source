# class for articulating RpEvents as sentences, with the ability to embed content strings in HTML before forming the sentence
class Articulator < Object
  attr_writer :subject, :direct_object, :indirect_object
  attr_reader :notification
  SUMMARY_USES = [ :subject, :verb, :direct_object, :indirect_object ]

  # Determine the class that articulates the given notifiable/key pair
  def self.make notification
    self.class_for(notification.notifiable, notification.key).new notification
  end

  def initialize notification
    @notification = notification
  end

  @@registry = {}

  # Register a class as articulating a particular key
  def self.register key, klass
    puts "Registering #{klass} to handle #{key}"
    @@registry[key] = klass
  end

  def self.registry
    puts 'Registered:'
    @@registry.each { |key, val| puts "\t#{key}: #{val}"}
  end

  def self.class_for notifiable, key
    key = "#{notifiable.class.to_s.underscore}.#{key}" unless key.match /\./
    @@registry[key] ||
      if klass = ((key.sub(/\./, '_').camelize+'Articulator').constantize rescue nil)
        self.register key, klass
      elsif klass = ((key.sub(/\..*$/, '').camelize+'Articulator').constantize rescue nil)
        self.register key, klass
      else
        Articulator
      end
  end

  def self.articulates *keys
    keys.each { |key|
      puts self.to_s + ' articulates ' + key
      Articulator.register key, self
    }
  end

  def summary forcements = {}
    finals = extract *(self.class::SUMMARY_USES + [forcements])
    finals[:default] = self.class::SUMMARY_USES.collect { |key| finals[key] }.compact.join ' '
    I18n.t(message_key(finals), finals).html_safe
  end

  def method_missing namesym, *args, &block
    if self.class::SUMMARY_USES.include? namesym
      instance_variable_get(:"@#{namesym}") || instance_variable_set(:"@#{namesym}",
                                                                     notification.notifiable.title_of(namesym, &block))
    end
  end

  # How to name a user, substituting 'you' when the viewer and the user are the same, optionally making it possessive
  def user_reference user, possessive = false
    if user
      if possessive
        user.id == notification.target.id ? 'your' : (user.name+"'s")
      else
        user.id == notification.target.id ? 'you' : user.name
      end
    else
      possessive ? 'your' : 'you'
    end
  end

  # Override the verb for a coherent expression
  def verb
    '<your verb here>'
  end

  protected

  # message_key specifies the place in the locale table where the message is found
  def message_key finals
    'notification.user.'+notification.key+'.summary'
  end

  private

  # Produce a hash of the specified instance variables, merged with values in a forcing hash
  def extract *args
    result = args.last.is_a?(Hash) ? args.pop : {}
    if args.empty?
      args = self.class::SUMMARY_USES
    else
      args |= result.keys
    end
    (args - result.keys).each { |arg|
      result[arg] = self.public_send(arg)
    }
    result
  end

end

class InvitationSentEventCreateArticulator < Articulator
  articulates 'invitation_sent_event.create'
  SUMMARY_USES = [ :subject, :verb, :direct_object ]

  def subject
    @subject ||= user_reference notification.notifiable.subject
  end

  def direct_object
    @direct_object ||= user_reference notification.notifiable.direct_object
  end

  def verb
    'invited'
  end
end

class InvitationAcceptedEventCreateArticulator < Articulator
  articulates 'invitation_accepted_event.create'
  SUMMARY_USES = [ :subject, :verb, :direct_object ]

  def direct_object
    @direct_object ||= user_reference notification.notifiable.direct_object, true
  end

  def verb
    'accepted'
  end
end

class SharedEventCreateArticulator < Articulator
  articulates 'shared_event.create'
  SUMMARY_USES = [ :subject, :verb, :direct_object, :indirect_object, :topic, :message ]

  def indirect_object
    @indirect_object ||= user_reference notification.notifiable.indirect_object
  end

  # what was shared
  def direct_object
    notification.notifiable.shared.decorate.title
  end

  def verb
    'shared'
  end

  # Our message key discriminates depending on whether there's a message or not
  def message_key contents
    super + "_with#{'out' unless contents[:message].present?}_message"
  end
end

