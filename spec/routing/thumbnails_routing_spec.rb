require "spec_helper"

describe ThumbnailsController do
  describe "routing" do

    it "routes to #index" do
      get("/thumbnails").should route_to("thumbnails#index")
    end

    it "routes to #new" do
      get("/thumbnails/new").should route_to("thumbnails#new")
    end

    it "routes to #show" do
      get("/thumbnails/1").should route_to("thumbnails#show", :id => "1")
    end

    it "routes to #edit" do
      get("/thumbnails/1/edit").should route_to("thumbnails#edit", :id => "1")
    end

    it "routes to #create" do
      post("/thumbnails").should route_to("thumbnails#create")
    end

    it "routes to #update" do
      put("/thumbnails/1").should route_to("thumbnails#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/thumbnails/1").should route_to("thumbnails#destroy", :id => "1")
    end

  end
end
