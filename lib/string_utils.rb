def splitstr(str, ncols=80)
  str = HTMLEntities.new.decode(str)
  out = []
  line = ""
  str.split(/\s+/).each do |word|
    if (line.length + word.length) >= ncols
      out << line
      line = ""
    end
    line << word+" "
  end
  out << line if line.length > 0
  out
end

# Return an enumeration of a series of strings, separated by ',' except for the last two separated by 'and'
# RETURN BLANK STRING IF STRS ARE EMPTY
def strjoin strs, before = "", after = "", joiner = ', '
  if strs.keep_if { |str| !str.blank? }.size > 0
    last = strs.pop
    liststr = strs.join joiner
    liststr += " and " unless liststr.blank?
    before+liststr+last+after
  else
    ""
  end
end

# Join strings into a "i, j and k" list
def liststrs(strs)
  return "" if strs.empty?
  if (strs.count == 1)
    strs[0]
  else
    last = strs.pop
    [strs.join(', '), last].join(' and ')
  end
end

# Two strings with space-separated words: merge them uniquely
def merge_word_strings str1, str2
  return str2||"" if str1.blank?
  return str1 if str2.blank?
  (str1.split(/\s+/) + str2.split(/\s+/)).uniq.join(' ')
end
