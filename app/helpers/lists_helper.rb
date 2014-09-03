module ListsHelper

  def lists_table
    stream_table [ "ID", "Name", "Description", "Included Tags" ]
  end

=begin
  def lists_header
    render "index_stream_header"
  end

  def list_header
    render "show_stream_header"
  end
=end
end
