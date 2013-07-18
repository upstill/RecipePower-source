def splitstr(str, ncols=80)
  debugger
  out = []
  line = ""
  str.split(/\s*/).each do |word|
    if (line.length + word.length) >= ncols
      out << line
      line = word
    else
      line << word+" "
    end
  end
  out << line if line.length > 0
  out
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