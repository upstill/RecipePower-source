module CardsHelper
  def object_display_class object
    if object.class == User
      if object == current_user
        "viewer"
      elsif current_user.follows? object
        "friend"
      else
        "user"
      end
    else
      object.class.to_s.underscore
    end
  end
end