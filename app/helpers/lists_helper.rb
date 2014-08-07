module ListsHelper

  def lists_table
    stream_table [ "Name", "Description" ]
  end

  def list_show
    stream_masonry
  end
end
