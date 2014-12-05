class CollectibleController < ApplicationController
  def collect
    update_and_decorate # Generate a FeedEntryDecorator as @feed_entry and prepares it for editing
    if current_user
      if params[:oust]
        @decorator.remove_from_collection current_user.id
      else
        @decorator.add_to_collection current_user.id
      end
      @decorator.object.save
      render :errors if post_resource_errors @decorator.object
    else
      flash[:alert] = "Sorry, you need to be logged in to collect something."
      render :errors
    end
  end
end
