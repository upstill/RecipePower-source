class Users::NotificationsWithDeviseController < ActivityNotification::NotificationsWithDeviseController

  # When a notification requires authentication (i.e., no user is logged in), provide a page to use
  # as background for the login dialog
  def self.show_page blocked_request, &block
    uri = URI blocked_request
    if match = uri.path.match(%r{^/users/(\d*)/notifications/(\d*)/(\w*)$})
      notif_id, action = match[2..3]
      notif = ActivityNotification::Notification.find_by id: notif_id.to_i
      case notif.notifiable_type
        when 'RpEvent'
          RpEventsController.show_page(notif.notifiable, &block) rescue nil
      end
    end
  end

  # Authenticate devise resource by Devise (e.g. calling authenticate_user! method).
  # @api protected
  # @todo Needs to call authenticate method by more secure way
  # @return [Responce] Redirects for unsigned in target by Devise, returns HTTP 403 without neccesary target method or returns 400 when request parameters are not enough
=begin
  def authenticate_devise_resource!
    begin
      super
    rescue Exception => e
      # Handle Warden exception for not having the right user logged in
      x=2
    end
  end
=end

  # GET /:target_type/:target_id/notifications
  def index
    set_index_options
    load_index if params.has_key?(:reload) ? params[:reload].to_s.to_boolean : true
    smartrender unless (params[:for] || '') == 'counter'
    # By default, goes to index.json.rb to replace the counter in the menu bar.
  end

  # POST /:target_type/:target_id/notifications/open_all
  # def open_all
  #   super
  # end

  # GET /:target_type/:target_id/notifications/:id
  # def show
  #   super
  # end

  # DELETE /:target_type/:target_id/notifications/:id
  # def destroy
  #   super
  # end

  # POST /:target_type/:target_id/notifications/:id/open
  # def open
  #   super
  # end

  # Moves to notifiable_path of the notification.
  #
  # GET /:target_type/:target_id/notifications/:id/move
  # @overload open(params)
  #   @param [Hash] params Request parameters
  #   @option params [String] :open    ('false') Whether the notification will be opened
  #   @option params [String] :filter  (nil)     Filter option to load notification index (Nothing as auto, 'opened' or 'unopened')
  #   @option params [String] :limit   (nil)     Limit to query for notifications
  #   @option params [String] :reload  ('true')  Whether notification index will be reloaded
  #   @return [Responce] JavaScript view for ajax request or redirects to back as default
  def move
    begin
      @notification.open! if params[:open].to_s.to_boolean
    rescue Exception => e
      # Handle Warden exception for not having the right user logged in
      x=2
    end

  end

  # No action routing
  # This method needs to be public since it is called from view helper
  # def target_view_path
  #   super
  # end

  # protected

  # def set_target
  #   super
  # end

  # def set_notification
  #   super
  # end

  # def set_index_options
  #   super
  # end

  # def load_index
  #   super
  # end

  # def controller_path
  #   super
  #   Users::NotificationsController.controller_path
  # end

  # def set_view_prefixes
  #   super
  # end

  # def return_back_or_ajax
  #   super
  # end

  # def authenticate_devise_resource!
  #   super
  # end

  # def authenticate_target!
  #   super
  # end
end
