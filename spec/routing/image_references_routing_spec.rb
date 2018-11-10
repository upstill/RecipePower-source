require "spec_helper"

describe ImageReferencesController do
  describe "routing" do

    it "routes to #index" do
      get("/image_references").should route_to("image_references#index")
    end

    it "routes to #new" do
      get("/image_references/new").should route_to("image_references#new")
    end

    it "routes to #show" do
      get("/image_references/1").should route_to("image_references#show", :id => "1")
    end

    it "routes to #edit" do
      get("/image_references/1/edit").should route_to("image_references#edit", :id => "1")
    end

    it "routes to #create" do
      post("/image_references").should route_to("image_references#create")
    end

    it "routes to #update" do
      put("/image_references/1").should route_to("image_references#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/image_references/1").should route_to("image_references#destroy", :id => "1")
    end

  end
end
