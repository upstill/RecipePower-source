module AdminHelper

  def user_admin_table_row row, field
    case field
    when :handle
      link_to_modal row[:handle], user_path(row[:user])
    when :add_time, :last_visit
      row[field] ? time_ago_in_words(row[field]) : ""
    when :invites
      (row[:invites] > 0) ? "#{row[:invites].to_s}(#{row[:accepts].to_s})" : ""
    end
  end

  def aggregate_admin_table_row row, field
     format("%.2f", row[field]) if row[field].class == Float
  end

end
