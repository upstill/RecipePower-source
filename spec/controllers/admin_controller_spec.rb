require 'spec_helper'

describe AdminController do

  describe "GET 'aggregate_user_table'" do
    it "returns http success" do
      get 'aggregate_user_table'
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
