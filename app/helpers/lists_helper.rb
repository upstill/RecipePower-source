module ListsHelper

  def lists_table
    stream_table [ "ID", "Name", "Description", "Included Tags" ]
  end

  def list_show
    stream_masonry
  end
end
