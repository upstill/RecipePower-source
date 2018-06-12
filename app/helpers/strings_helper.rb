module StringsHelper

  # Present a collection of strings as a label followed by an indented list--all html safe
  def summarize_set header, set, separator=nil
    separator = summary_separator separator
    set = set.flatten.keep_if &:present?
    if set.size > 0
      if header.present?
        set.unshift header.html_safe
        safe_join set, summary_separator(separator)
      else
        safe_join set, separator
      end
    else
      ''.html_safe
    end
  end

  def summary_separator insep=nil
    insep ? (insep + '&nbsp;&nbsp;&nbsp;&nbsp;'.html_safe) : tag(:br)
  end

end