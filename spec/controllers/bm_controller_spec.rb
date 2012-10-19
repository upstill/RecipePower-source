require 'spec_helper'

describe BmController do

  describe "GET 'bookmarklet'" do
    it "should be successful" do
      get 'bookmarklet'
      response.should be_success
    end
  end

end
