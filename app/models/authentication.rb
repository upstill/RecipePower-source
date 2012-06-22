class Authentication < ActiveRecord::Base
  belongs_to :user
  attr_accessible :user_id, :provider, :uid
  
  def provider_name
    case provider
    when "open_id"
      "OpenID"
    when "google_oauth2"
      "Google"
    else
      provider.titleize
    end
  end
  
end
