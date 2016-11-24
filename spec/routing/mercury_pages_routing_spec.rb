require "spec_helper"

describe MercuryPagesController do
  describe "routing" do

    it "routes to #index" do
      get("/mercury_pages").should route_to("mercury_pages#index")
    end

    it "routes to #new" do
      get("/mercury_pages/new").should route_to("mercury_pages#new")
    end

    it "routes to #show" do
      get("/mercury_pages/1").should route_to("mercury_pages#show", :id => "1")
    end

    it "routes to #edit" do
      get("/mercury_pages/1/edit").should route_to("mercury_pages#edit", :id => "1")
    end

    it "routes to #create" do
      post("/mercury_pages").should route_to("mercury_pages#create")
    end

    it "routes to #update" do
      put("/mercury_pages/1").should route_to("mercury_pages#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/mercury_pages/1").should route_to("mercury_pages#destroy", :id => "1")
    end

  end
end
