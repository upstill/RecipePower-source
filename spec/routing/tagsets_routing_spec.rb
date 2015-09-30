require "spec_helper"

describe TagsetsController do
  describe "routing" do

    it "routes to #index" do
      get("/tagsets").should route_to("tagsets#index")
    end

    it "routes to #new" do
      get("/tagsets/new").should route_to("tagsets#new")
    end

    it "routes to #show" do
      get("/tagsets/1").should route_to("tagsets#show", :id => "1")
    end

    it "routes to #edit" do
      get("/tagsets/1/edit").should route_to("tagsets#edit", :id => "1")
    end

    it "routes to #create" do
      post("/tagsets").should route_to("tagsets#create")
    end

    it "routes to #update" do
      put("/tagsets/1").should route_to("tagsets#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/tagsets/1").should route_to("tagsets#destroy", :id => "1")
    end

  end
end
