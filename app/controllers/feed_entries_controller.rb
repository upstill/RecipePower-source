class FeedEntriesController < ApplicationController
  def collect
    @user = current_user
    @feed_entry = FeedEntry.find params[:id]
    @user.touch @feed_entry, true
    @feed_entry.prep_params @user.id
    # redirect_to :edit
  end

  def edit
    fe = FeedEntry.find params[:id]
  end

  def update
    fe = FeedEntry.find params[:id]
  end
end
