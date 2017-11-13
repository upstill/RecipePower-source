# class for articulating RpEvents as sentences, with the ability to embed content strings in HTML before forming the sentence
class Articulator < Object
  attr_writer :subject, :direct_object, :indirect_object
  attr_reader :notification

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

  def sentence
    [ subject, verb, direct_object, indirect_object ].compact.join ' '
  end

  def method_missing namesym, *args, &block
    if [:subject, :direct_object, :indirect_object].include? namesym
      instance_variable_get(:"@#{namesym}") ||
          if entity = notification.notifiable.method(namesym).call(*args)
            decorator = entity.decorate
            instance_variable_set :"@#{namesym}", block_given? ? (yield decorator) : decorator.name
          else
            return super
          end
    else
      super
    end
  end

  # How to name a user, substituting 'you' when the viewer and the user are the same
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

end

class InvitationSentEventCreateArticulator < Articulator
  articulates 'invitation_sent_event.create'

  def subject
    @subject ||= user_reference notification.notifiable.subject
  end

  def direct_object
    @direct_object ||= user_reference notification.notifiable.direct_object
  end

  def sentence
    "#{subject} #{verb} #{direct_object} to join RecipePower".html_safe
  end

  def verb
    'invited'
  end
end

class InvitationAcceptedEventCreateArticulator < Articulator
  articulates 'invitation_accepted_event.create'

  def sentence
    "#{subject} #{verb} #{direct_object} invitation to RecipePower".html_safe
  end

  def direct_object
    @direct_object ||= user_reference notification.notifiable.direct_object, true
  end

  def verb
    'accepted'
  end
end

