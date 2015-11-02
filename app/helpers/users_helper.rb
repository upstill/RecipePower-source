module UsersHelper

  def followees_list f, me, channels
    # followee_tokens is a virtual attribute, an array of booleans for checking and unchecking followees
    f.fields_for :followee_tokens do |builder|
  	   me.friend_candidates(channels).map { |other|
  		 builder.check_box(other.id.to_s, :checked => me.follows?(other.id)) + builder.label(other.id.to_s, other.username)
  	   }.compact.join('<br>').html_safe
    end
  end
  
  def subscriptions_list f, me, channels
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
    return ''.html_safe if user == current_user_or_guest
    if size.is_a? Hash
      size, options = nil, size
    end
    do_label = options.delete :label
    label = ''
    if current_user_or_guest.follows? user
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

  # Account for the difference between the id for an entity type and its label
  def user_associated_label entity_type
    (entity_type=='friends') ? 'cookmates' : entity_type
  end

  def user_linktitle user
    user.fullname.if_present || user.username.if_present || user.handle
  end

  def user_homelink user, options={}
    (data = (options[:data] || {}))[:report] = polymorphic_path [:touch, user]
    if user.id == current_user_or_guest_id
      subclass = 'viewer'
    else
      subclass = 'friend'
    end
    klass = "#{options[:class]} entity user #{subclass}"
    # Default submission is partial
    action = options[:action] || :collection
    link_to_submit user_linktitle(user),
                   polymorphic_path([action, user]),
                   {mode: :partial}.merge(options).merge(data: data, class: klass).except(:action)
  end

  # Operate on a set of tag specifications as defined in UserDecorator for directing a list search
  # Enhance each tokeninput with css class, css id and (as appropriate) owner specifier)
  def classify_listtags tokeninputs
    tokeninputs.each { |tokeninput|
      tokeninput[:cssid] = "choice_#{tokeninput[:id]}"

      case tokeninput[:status]
        when :'my own', :'my collected'
          tokeninput[:cssclass] = 'owned'
        when :'owned', :'collected'
          tokeninput[:cssclass] = 'friends'
          tokeninput[:name] = "#{tokeninput[:name]} (#{tokeninput[:owner_name]})"
      end
    }
    tokeninputs
  end
end
