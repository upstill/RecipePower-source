require 'spec_helper'

describe "Lists" do
  describe "GET /lists" do
    it "has presenter features" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get lists_path
      response.status.should be(200)

    end
  end

  describe "GET /lists?stream" do

  end
end
