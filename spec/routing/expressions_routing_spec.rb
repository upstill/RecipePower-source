require "spec_helper"

describe ExpressionsController do
  describe "routing" do

    it "routes to #index" do
      get("/expressions").should route_to("expressions#index")
    end

    it "routes to #new" do
      get("/expressions/new").should route_to("expressions#new")
    end

    it "routes to #show" do
      get("/expressions/1").should route_to("expressions#show", :id => "1")
    end

    it "routes to #edit" do
      get("/expressions/1/edit").should route_to("expressions#edit", :id => "1")
    end

    it "routes to #create" do
      post("/expressions").should route_to("expressions#create")
    end

    it "routes to #update" do
      put("/expressions/1").should route_to("expressions#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/expressions/1").should route_to("expressions#destroy", :id => "1")
    end

  end
end
