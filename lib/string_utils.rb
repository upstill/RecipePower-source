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