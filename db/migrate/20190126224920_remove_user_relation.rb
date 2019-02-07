class RemoveUserRelation < ActiveRecord::Migration[5.0]
  def up
    # Make user relations collection-based w/o use of the UserRelation model

    # Get follower and followee for each relation
    q = 'SELECT "user_relations"."follower_id", "user_relations"."followee_id" FROM "user_relations" ;'
    map = []
    ActiveRecord::Base.connection.execute(q).each do |h|
      # logger.debug "Relation of follower #{h['follower_id']} to followee #{h['followee_id']}"
      # puts "Relation of follower #{h['follower_id']} to followee #{h['followee_id']}"
      id = h['follower_id']
      map[id] ||= []
      map[id] << h['followee_id']
    end
    # Now we have an array that maps follower ids to a list of followee ids.
    # The follower should 'collect' all of its followees
    map.each_index do |follower_id|
      if (followee_list = map[follower_id]) && (follower = User.find_by id: follower_id )
        User.where(id: followee_list).each { |followee| follower.collect followee }
      end
    end
	  drop_table 'user_relations'
  end
end
