# Split a string, emitting delimiters and punctuation as separate entities
# If the block is given, call it with the found token and the offset within the string at which it's found
def tokenize str, &block
  if block_given?
    offset = 0
    out = []
    while str.present? do
      str = str.sub /(^\s*)([^\]\[)(}{,.?\s]+|[()\[\]{},.?])/, ''
      offset += $1.length
      block.call $2, offset
      offset += $2.length
      out << $2
    end
  else
    str.scan /[^\]\[)(}{,.?\s]+|[()\[\]{},.?]/
  end
end

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

def labelled_quantity count, label, empty_msg = nil
  qstr =
  case count
    when 0
      empty_msg || "No #{label.pluralize}"
    when 1
      "1 #{label}"
    else
      "#{count} #{label.pluralize}"
  end
  qstr.html_safe
end

# Return an enumeration of a series of strings, separated by ',' except for the last two separated by 'and'
# RETURN BLANK STRING IF STRS ARE EMPTY
def strjoin strs, before = "", after = "", joiner = ',', line_end=' '
  if strs.keep_if { |str| !str.blank? }.size > 0
    last = strs.pop
    liststr = strs.join (joiner+line_end)
    liststr += " and#{line_end}" unless liststr.blank?
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

# Convert a name (possibly with embedded '::') to a class
def string_to_class string
  chain = string.split "::"
  i=0
  res = chain.inject(Module) do |ans,obj|
    break if ans.nil?
    i+=1
    klass = ans.const_get(obj)
    # Make sure the current obj is a valid class
    # Or it's a module but not the last element,
    # as the last element should be a class
    klass.is_a?(Class) || (klass.is_a?(Module) and i != chain.length) ? klass : nil
  end
rescue NameError
  nil
end

def active_record_class_from_association_method_name methstr
  methstr = methstr.to_s.sub( /[<=]*$/, '').sub(/_ids$/, '')
  methstr.singularize.camelize.constantize
end
