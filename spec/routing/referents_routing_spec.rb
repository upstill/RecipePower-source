require "spec_helper"

describe ReferentsController do
  describe "routing" do

    it "routes to #index" do
      get("/referents").should route_to("referents#index")
    end

    it "routes to #new" do
      get("/referents/new").should route_to("referents#new")
    end

    it "routes to #show" do
      get("/referents/1").should route_to("referents#show", :id => "1")
    end

    it "routes to #edit" do
      get("/referents/1/edit").should route_to("referents#edit", :id => "1")
    end

    it "routes to #create" do
      post("/referents").should route_to("referents#create")
    end

    it "routes to #update" do
      put("/referents/1").should route_to("referents#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/referents/1").should route_to("referents#destroy", :id => "1")
    end

  end
end
