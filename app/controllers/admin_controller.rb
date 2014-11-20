require 'table_presenter.rb'

class AdminController < ApplicationController

  def data
    case (@type = params[:type] || "aggregate_user").to_sym
      when :single_user
        # Generate the aggregate_user_table table
        stats = []
        session[:sort_field] = (params[:sort_by] || session[:sort_field] || :id)
        User.all.each do |user|
          accepts = ((invitees = User.where(:invited_by_id => user.id)).count > 0) ?
              invitees.where('invitation_accepted_at IS NOT NULL').count : 0
          num_recipes = user.recipes.size
          num_tags = Tagging.where(user_id: user.id).count
          stats[user.id] = RpEvent.user_stats(user, 1.month.ago).merge(
              user: user,
              id: user.id,
              handle: user.handle,
              num_recipes: num_recipes,
              num_tags: num_tags,
              num_tags_per_recipe: (num_recipes > 0) ? num_tags.to_f/num_recipes : 0.0,
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
        @table = TablePresenter.new "Users", stats,
                                            id: "ID",
                                            handle: "Handle",
                                            num_recipes: "#Recipes",
                                            num_tags: "#Tags",
                                            num_tags_per_recipe: "#Tags per recipe",
                                            edit_count: "#Edits",
                                            add_time: "Time Since Recipe Added",
                                            last_visit: "Time Since Last Visit",
                                            recent_visits: "#visits in last month",
                                            invites: "Invitations Issued (Accepted)"

        sortfield = session[:sort_field].to_sym
        descending = [:num_recipes, :num_tags, :num_tags_per_recipe, :edit_count, :add_time, :last_visit, :recent_visits, :invites ].include?(sortfield)
        @table.sort sortfield, descending
      when :aggregate_user
        # Now get the aggregates table: do analytics for the given intervals, including an all-time column
        @table = AnalyticsServices.tabulate :monthly, 4, true
    end
    render "#{@type}_table"
  end

  def control
  end

  def toggle
    session[:admin_view] = params[:on] == "true"
    flash[:popup] = "Admin View is now #{session[:admin_view] ? 'On' : 'Off' }"
  end
end
