module UsersHelper
   def followees_list f, me, channels
     # followee_tokens is a virtual attribute, an array of booleans for checking and unchecking followees
     f.fields_for :followee_tokens do |builder|
   	   User.all.collect { |other|
   	     next if((channels != other.channel?) || !User.public?(other.id) || (other.id == me.id))
   		 builder.check_box(other.id.to_s, :checked => me.follows?(other.id)) + builder.label(other.id.to_s, other.username)
   	   }.compact.join('<br>').html_safe
     end
   end
end
