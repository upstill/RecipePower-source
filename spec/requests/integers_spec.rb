require 'spec_helper'

describe "Ingeters" do
  describe "GET /integers" do
    it "should have basic streaming features" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get integers_path
      response.status.should be(200)
    end
  end
end
