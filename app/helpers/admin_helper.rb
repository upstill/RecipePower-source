module AdminHelper

  def single_user_table_row row, field
    case field
      when :handle
        link_to_submit row[:handle], user_path(row[:user]), mode: :modal
      when :add_time, :last_visit
        row[field] ? time_ago_in_words(row[field]) : ""
      when :invites
        (row[:invites] > 0) ? "#{row[:invites].to_s}(#{row[:accepts].to_s})" : ""
      when :num_tags_per_recipe
        "NaN" if row[:num_recipes] == 0
    end
  end

  def aggregate_user_table_row row, field
    format("%.2f", row[field]) if row[field].class == Float
  end

end
