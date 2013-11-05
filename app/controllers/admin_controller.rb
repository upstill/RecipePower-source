require 'table_presenter.rb'

class AdminController < ApplicationController
  def stats
    stats = []
    session[:sort_field] = (params[:sort_by] || session[:sort_field] || :id)
    User.all.each do |user|
      accepts = ((invitees = User.where(:invited_by_id => user.id)).count > 0) ?
          invitees.where('invitation_accepted_at IS NOT NULL').count : 0

      stats[user.id] = RpEvent.user_stats(user.id).merge(
        user: user,
        id: user.id,
        handle: user.handle,
        num_recipes: user.recipes.size,
        edit_count: 0,
        accepts: accepts,
        invites: invitees.count
      )
    end
    Rcpref.all.each { |rr|
      if user_stats = stats[rr.user_id]
        user_stats[:add_time] = rr.created_at if user_stats[:add_time].nil? || (rr.created_at > user_stats[:add_time])
        user_stats[:edit_count] += rr.edit_count
      end
    }
    @display_table = TablePresenter.new stats,
      id: "ID",
      handle: "Handle",
      num_recipes: "#Recipes",
      edit_count: "#Edits",
      add_time: "Time Since Recipe Added",
      last_visit: "Time Since Last Visit",
      recent_visits: "#visits in last month",
      invites: "Invitations Issued (Accepted)"

    sortfield = session[:sort_field].to_sym
    descending = [:num_recipes, :edit_count, :add_time, :last_visit, :recent_visits, :invites ].include?(sortfield)
    @display_table.sort sortfield, descending
  end

  def control
  end
end
