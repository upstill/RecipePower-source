require 'spec_helper'

describe NotificationsController do

  describe "GET 'accept'" do
    it "should be successful" do
      get 'accept'
      response.should be_success
    end
  end

end
