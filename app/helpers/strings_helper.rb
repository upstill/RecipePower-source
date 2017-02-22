module StringsHelper

  # Present a collection of strings as a label followed by an indented list--all html safe
  def summarize_set label, set, separator=nil
    separator = summary_separator separator
    purged = set.flatten.keep_if { |line_item| line_item.present? }
    if purged.size > 0
      purged.unshift label.html_safe if label.present?
      safe_join purged, separator
    else
      ''.html_safe
    end
  end

  def summary_separator insep=nil
    insep ? (insep + '&nbsp;&nbsp;&nbsp;&nbsp;'.html_safe) : tag(:br)
  end

end