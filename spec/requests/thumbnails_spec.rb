require 'spec_helper'

describe "Thumbnails" do
  describe "GET /thumbnails" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get thumbnails_path
      response.status.should be(200)
    end
  end
end
