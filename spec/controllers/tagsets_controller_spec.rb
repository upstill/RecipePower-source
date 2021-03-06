require 'spec_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator.  If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails.  There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.
#
# Compared to earlier versions of this generator, there is very limited use of
# stubs and message expectations in this spec.  Stubs are only used when there
# is no simpler way to get a handle on the object needed for the example.
# Message expectations are only used when there is no simpler way to specify
# that an instance is receiving a specific message.

describe TagsetsController do

  # This should return the minimal set of attributes required to create a valid
  # Tagset. As you add validations to Tagset, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { {  } }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # TagsetsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET index" do
    it "assigns all tagsets as @tagsets" do
      tagset = Tagset.create! valid_attributes
      get :index, {}, valid_session
      assigns(:tagsets).should eq([tagset])
    end
  end

  describe "GET show" do
    it "assigns the requested tagset as @tagset" do
      tagset = Tagset.create! valid_attributes
      get :show, {:id => tagset.to_param}, valid_session
      assigns(:tagset).should eq(tagset)
    end
  end

  describe "GET new" do
    it "assigns a new tagset as @tagset" do
      get :new, {}, valid_session
      assigns(:tagset).should be_a_new(Tagset)
    end
  end

  describe "GET edit" do
    it "assigns the requested tagset as @tagset" do
      tagset = Tagset.create! valid_attributes
      get :edit, {:id => tagset.to_param}, valid_session
      assigns(:tagset).should eq(tagset)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new Tagset" do
        expect {
          post :create, {:tagset => valid_attributes}, valid_session
        }.to change(Tagset, :count).by(1)
      end

      it "assigns a newly created tagset as @tagset" do
        post :create, {:tagset => valid_attributes}, valid_session
        assigns(:tagset).should be_a(Tagset)
        assigns(:tagset).should be_persisted
      end

      it "redirects to the created tagset" do
        post :create, {:tagset => valid_attributes}, valid_session
        response.should redirect_to(Tagset.last)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved tagset as @tagset" do
        # Trigger the behavior that occurs when invalid params are submitted
        Tagset.any_instance.stub(:save).and_return(false)
        post :create, {:tagset => {  }}, valid_session
        assigns(:tagset).should be_a_new(Tagset)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        Tagset.any_instance.stub(:save).and_return(false)
        post :create, {:tagset => {  }}, valid_session
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested tagset" do
        tagset = Tagset.create! valid_attributes
        # Assuming there are no other tagsets in the database, this
        # specifies that the Tagset created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        Tagset.any_instance.should_receive(:update).with({ "these" => "params" })
        put :update, {:id => tagset.to_param, :tagset => { "these" => "params" }}, valid_session
      end

      it "assigns the requested tagset as @tagset" do
        tagset = Tagset.create! valid_attributes
        put :update, {:id => tagset.to_param, :tagset => valid_attributes}, valid_session
        assigns(:tagset).should eq(tagset)
      end

      it "redirects to the tagset" do
        tagset = Tagset.create! valid_attributes
        put :update, {:id => tagset.to_param, :tagset => valid_attributes}, valid_session
        response.should redirect_to(tagset)
      end
    end

    describe "with invalid params" do
      it "assigns the tagset as @tagset" do
        tagset = Tagset.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Tagset.any_instance.stub(:save).and_return(false)
        put :update, {:id => tagset.to_param, :tagset => {  }}, valid_session
        assigns(:tagset).should eq(tagset)
      end

      it "re-renders the 'edit' template" do
        tagset = Tagset.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Tagset.any_instance.stub(:save).and_return(false)
        put :update, {:id => tagset.to_param, :tagset => {  }}, valid_session
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested tagset" do
      tagset = Tagset.create! valid_attributes
      expect {
        delete :destroy, {:id => tagset.to_param}, valid_session
      }.to change(Tagset, :count).by(-1)
    end

    it "redirects to the tagsets list" do
      tagset = Tagset.create! valid_attributes
      delete :destroy, {:id => tagset.to_param}, valid_session
      response.should redirect_to(tagsets_url)
    end
  end

end
