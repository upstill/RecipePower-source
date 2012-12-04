class CollectionController < ApplicationController
  
  def index
    @user_id = current_user_or_guest_id 
    user = User.find(@user_id)
    @collection = user.browser
  end
  
  def show
  end

  def new
  end

  def edit
  end

  def create
  end

  def relist
  end

  def update
    debugger
  end
end
