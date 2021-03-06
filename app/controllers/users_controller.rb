require 'suggestion.rb'
require 'filtered_presenter.rb'

class UsersController < CollectibleController
  
  rescue_from ActiveRecord::RecordNotFound, :with => :not_found
  before_action :login_required, :except => [:touch, :unsubscribe, :create, :new, :show, :index, :identify, :profile, :sign_up, :collection ]
  before_action :authenticate_user!, :except => [:touch, :unsubscribe, :new, :show, :index, :identify, :profile, :collection]

  # Take a tokenInput query string and match the input against the given user's set of friends
  def match_friends
    me = User.find params[:id]
    respond_to do |format|
      format.json { 
        friends = me.match_friends(params[:q]).collect { |friend|
          name = friend.handle
          name << " (#{friend.email})"
          { id: friend.id.to_s, name: name }
        }
        if friends.empty? 
          if params[:q].match(Devise::email_regexp)
            # A "valid" address goes back paired with itself
            friends = [ { id: params[:q], name: params[:q] } ]
          end
        end
        render :json => friends
      }
    end
  end
  
  # GET /users
  # GET /users.xml
  def index
    # 'index' page may be calling itself with filter parameters in the name and tagtype
    @select = params[:select]
    response_service.title = (@select=='followees') ? 'Friends' : 'People'
    smartrender 
  end

  # Add a user to the friends of the current user
  def follow
    if current_user
      update_and_decorate 
      if current_user.follows? @user
        current_user.followees.delete @user
        msg = "You're no longer following '#{@user.handle}'."
      else
        current_user.followees << @user
        msg = "You're now following '#{@user.handle}'."
      end
      current_user.save
      if resource_errors_to_flash(current_user)
        render :errors
      else
        flash[:popup] = msg
        render :follow
      end
    else
      flash[:alert] = "Sorry, you need to be logged in to follow someone."
      render :errors
    end
  end

  def new
    response_service.user = User.new
    response_service.title = "Create RecipePower Account"
  end
  
  # DELETE /users/1
  # DELETE /users/1.xml
  def destroy
    response_service.user = User.find params[:id]
    response_service.user.destroy
    respond_to do |format|
      format.html { redirect_to(users_url) }
      format.xml  { head :ok }
    end
  end
  
  def show
    @active_menu = params[:id].to_s == User.current_or_guest.id ? :home : :friends
    update_and_decorate touch: true
    smartrender 
  end

  # Show the user's recently-viewed recipes
  def recent
    @active_menu = params[:id].to_s == User.current_or_guest.id ? :home : :collections
    update_and_decorate 
    @empty_msg = "As you check out things in RecipePower, they will be remembered here."
    response_service.title = 'Recently Viewed'
    smartrender 
  end

  # Show the user's entire collection
  def collection
    update_and_decorate touch: true
    case label = (params[:result_type].if_present || '???').split('.').first
    when 'recipes'
      label = 'cookmarks'
    when 'lists'
      label = 'treasuries'
    end
    if response_service.user.id == User.current_or_guest.id
      case params[:result_type]
      when 'recipes', 'cookmarks'
        @empty_msg = "You haven't collected anything. Why not install the #{view_context.link_to_submit 'Cookmark Button', '/cookmark.json', :mode => :modal} and go get something?".html_safe
      when 'feeds'
        @empty_msg = "There are no feeds in your collection. You might want to #{view_context.link_to_submit 'check out our existing offerings here', '/feeds.json'}.".html_safe
      when 'lists.collected'
        @empty_msg = "No treasuries collected? You might want to #{view_context.link_to_submit 'see what\'s available here', '/lists.json'}.".html_safe
      when 'lists', 'lists.owned'
        @empty_msg = "Haven't compiled any treasuries? Start one #{view_context.link_to_dialog('here', new_list_path, class: 'transient')} or see what's on offer #{view_context.link_to_submit('here', '/lists.json')}.".html_safe
      when 'friends'
        @empty_msg = "See what other people are up to! #{view_context.link_to_submit 'Find potential friends here', '/users.json'}--or #{view_context.link_to_dialog('invite one of your own friends!', new_user_invitation_path)}!.".html_safe
      else
        @empty_msg = "No #{label} to be found..."
      end
      @active_menu = :collections
    else
      response_service.title = "#{response_service.user.handle}'s #{label}"
      @empty_msg = 'They haven\'t collected anything?!? Why not Share something with them?'
      @active_menu = :friends
    end
    smartrender 
  end

  # Show the user's recently-viewed recipes
  def biglist
    update_and_decorate 
    @active_menu = :collections
    response_service.title = 'The Big List'
    smartrender 
  end

  def not_found
    redirect_to root_path, :notice => 'User not found', method: 'get'
  end

  # With devise handling user creation, the only way we get here is from the 'identify' page.
  # If the user has provided an email address (whether in the 'new user' or 'existing user' section),
  # we try to match it to a user record. If no matchable email was provided, we create a new user.
  def create
  end
  
  # Remove a user from the friends of the current user
  def remove
    begin
      followee = User.find params[:id]
    rescue Exception => e
      flash[:error] = 'Couldn\'t find followee '+params[:id].to_s
    end
    if current_user && followee
      current_user.followees.delete followee
      current_user.save
      flash[:notice] = 'There you go! No longer following '+followee.handle
    else
      flash[:error] ||= ': No current user'
    end
    redirect_to root_path
  end

  def edit
    update_and_decorate
    @authentications = response_service.user.authentications if @decorator.id
    @section = params[:section] || 'profile'
    response_service.title = 'Edit Profile'
    if [ :about ].include? @section.to_sym
      render 'edit_aspect', locals: { aspect: @section.to_sym }
    else
      smartrender
    end
  end
  
  # Ask user for an email address for login purposes
  def identify
    response_service.user = User.new
    if omniauth = session[:omniauth]
      @provider = omniauth.provider.capitalize
      response_service.user.apply_omniauth(omniauth)
    end
  end
  
  def profile
    params[:id] = current_user.id if current_user
    update_and_decorate
    @authentications = response_service.user.authentications if @decorator.id
    @section = params[:section] || 'profile'
    response_service.title = 'My '+@section.capitalize
    smartrender action: 'edit'
  end

  def getpic
    update_and_decorate
  end

  # Turn off newsletter subscription
  def unsubscribe
    user_id = Rails.application.message_verifier(:unsubscribe).verify params[:id]
    @user = User.find user_id
    @user.subscribed = params[:user] && (params[:user][:subscribed] == 'true')
    update_and_decorate @user
    @user.save
    if @user.subscribed
      respond_to do |format|
        format.json { render json: { done: true, popup: 'Unsubscribe Reversed. Thanks for Reading!' } }
      end
    else
      smartrender modal_page: '/popup'
    end
  end

  def update
    if update_and_decorate
      if @updated = params[:form]
        flash[:popup] = 'Thanks for the update!'
      else
        response_service.title = 'Cookmarks from Update'
        flash[:message] = (response_service.user == current_user ? 'Your profile' : response_service.user.handle+"'s profile")+' has been updated.'
        # redirect_to action: 'collection'
        render 'collectible/update'
      end
    else
      @section = params[:user][:email] ? 'profile' : 'account'
      response_service.title = "Edit #{@section}"
      smartrender action: 'edit', mode: 'modal'
    end
  end

  def sendmail
    if update_and_decorate
      case request.method
      when 'PATCH', 'POST' # 'GET' request opens the dialog, 'PATCH' submits it
        if response_service.user.mail_subject.blank? && !(params[:confirmed] && (params[:confirmed] == '1'))
          # Go again
          flash[:alert] = 'No subject?!? If that\'s really what you want, send again.'
          @confirmed = '1'
        elsif response_service.user.mail_body.blank?
          flash.now[:error] = 'No message?!? Don\'t want to bother someone with an empty email!'
          render :errors
        else
          RpMailer.user_to_user(current_user, response_service.user).deliver_now
          flash[:popup] = 'Mail is on its way!'
          render :done
        end
      when 'GET'
        smartrender
      end
    end
  end

  private

  def user_params
    params.
        require(:user).
        permit(:image, :username, :first_name, :last_name, :fullname, :about, :email, :private, :role_id,
               {answers_attributes: %w{ answer _destroy question_id id }},
               {tag_selections_attributes: %w{ user_id tag_token _destroy tagset_id id }})
  end

end
