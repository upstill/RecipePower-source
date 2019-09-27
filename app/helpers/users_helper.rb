module UsersHelper

=begin
  def user_homelink user, options={}
    homelink user, options.merge(:action => :collection, :class => "#{options[:class]} #{user_subclass user}")
  end
=end

  # NB Currently out of use
  def followees_list f, me
    # followee_tokens is a virtual attribute, an array of booleans for checking and unchecking followees
    f.fields_for :followee_tokens do |builder|
  	   me.friend_candidates.map { |other|
  		 builder.check_box(other.id.to_s, :checked => me.follows?(other.id)) + builder.label(other.id.to_s, other.username)
  	   }.compact.join('<br>').html_safe
    end
  end

  # NB Currently out of use
  def subscriptions_list f, me
    # subscription_tokens is a virtual attribute, an array of booleans for checking and unchecking followees
    f.fields_for :subscription_tokens do |builder|
  	   Feed.where(approved: true).map { |feed|
  		   builder.check_box(feed.id.to_s, :checked => me.feeds.exists?(id: feed.id)) + builder.label(feed.id.to_s, feed.description)
  	   }.compact.join('<br>').html_safe
    end
  end
  
   def login_choices user
       both = !(user.username.empty? || user.email.empty?)
       ((both ? "either " : "")+
       (user.username ? "your username '#{user.username}'" : "")+
       (both ? " or " : "")+
       (user.email ? "your email '#{user.email}'" : "")).html_safe
   end

  # Present the 'follow' status of a user wrt the current user
  # options[:label] should be a boolean for whether to accompany the button with a label
  # options[:removable] denotes whether to offer an 'Unfollow' option or just report the status with a glyph
  def user_follow_button user, size = nil, options={}
    return ''.html_safe if user == User.current_or_guest
    if size.is_a? Hash
      size, options = nil, size
    end
    do_label = options.delete :label
    label = ''
    if User.current_or_guest.follows? user
      if options.delete :removable
        label = "&nbsp;Unfollow" if do_label
        button_to_submit label,
                         follow_user_path(user),
                         'glyph-minus',
                         size,
                         method: 'post',
                         title: "Unfollow #{user.handle}",
                         class: "follow-button",
                         id: dom_id(user)
      else
        label = '&nbsp;Following' if do_label
        sprite_glyph(:check,
                     options[:size],
                     title: "Following #{user.handle}",
                     class: "follow-button",
                     id: dom_id(user)) + label
      end
    else
      label = "&nbsp;Follow" if do_label
      button_to_submit label,
                       follow_user_path(user),
                       'glyph-plus',
                       size,
                       method: 'post',
                       title: "Follow #{user.handle}",
                       class: "follow-button",
                       id: dom_id(user)
    end
  end

  def user_follow_button_replacement user, options={}
    [ ".follow-button##{dom_id user}", user_follow_button(user, options) ]
  end

  def di_select
    menu_options = { class: "di-selector" }
    menu_options[:style] = "display: none;" if (alltags-curtags).empty?
    options = alltags.collect { |tag|
      content_tag :option, tag.name, { value: tag.id, style: ("display: none;" if curtags.include?(tag)) }.compact
    }.unshift(
        content_tag :option, "Pick #{curtags.empty? ? 'a' : 'Another'} Question", value: 0
    ).join.html_safe
    content_tag :select, options, menu_options # , class: "selectpicker"
  end

  # Operate on a set of tag specifications as defined in UserDecorator for directing a list search
  # Enhance each tokeninput with css class, css id and (as appropriate) owner specifier)
  def classify_listtags tokeninputs
    tokeninputs.each { |tokeninput|
      tokeninput[:cssid] = "choice_#{tokeninput[:id]}"
      tokeninput[:cssclass] = tokeninput[:status].to_s
      tokeninput[:name] << " (#{tokeninput[:owner_name]})" if tokeninput[:status] != :owned
    }
    tokeninputs
  end
end
