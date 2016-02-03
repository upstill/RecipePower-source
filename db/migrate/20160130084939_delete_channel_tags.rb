class DeleteChannelTags < ActiveRecord::Migration
  def up
    ExpressionDecorator.ref_check # Remove all Expressions that no longer connect to Referents
    List.assert 'healthy', User.find(1), create: true
    List.assert 'hot list', User.find(1), create: true
    t = Tag.find(16154)
    t.tagtype = 4
    t.save
    t = Tag.find(16155)
    t.tagtype = 0
    t.save
    t = Tag.find(16156)
    t.tagtype = 0
    t.save
    taggings = Tagging.where(tag_id: 16156)
    taggings.each { |tagging| tagging.tag_id = 1482; tagging.save }
    TagDecorator.ref_check true
    ChannelReferent.destroy_all
    remove_column :users, :channel_referent_id
    remove_column :users, :browser_serialized
  end
  def down
  end
end
