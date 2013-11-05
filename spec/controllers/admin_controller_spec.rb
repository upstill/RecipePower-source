require 'spec_helper'

describe AdminController do

  describe "GET 'stats'" do
    it "returns http success" do
      get 'stats'
      response.should be_success
    end
  end

  describe "GET 'control'" do
    it "returns http success" do
      get 'control'
      response.should be_success
    end
  end

end
