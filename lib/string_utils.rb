# Split a string, emitting delimiters and punctuation as separate entities
# If the block is given, call it with the found token and the offset within the string at which it's found
def tokenize str, terminates=false, &block
  if block_given?
    offset = 0
    while str.length > 0 do
      ostr = str
      # '/' is a separate token UNLESS surrounded by digit strings--a fraction
      str = ostr.sub /(^[ \t\r\f\v\u00a0]*)(\d+\/\d+|[^-\/\]\[)(}{;,.?\s\u00a0]+|[-()\/\[\]{};,.?\n])/i, '' # Pluck the next token
      spaces, token = $1, $2
      if token && ((str.length > 0) || terminates || token.match(/^[()\[\]{};,.?\n]/)) # This string really ends here (no continuation of non-delimiter)
        offset += spaces&.length || 0
        block.call token, offset unless token.empty?
        offset += token&.length || 0
      else
        return ostr # Return the unprocessed remainder of the string (which may be blank)
      end
    end
    ''
  else
    tokens = []
    while str.length > 0
      str = str.sub /(^[ \t\r\f\v\u00a0]*)([^\]\[)(}{;,.?\s\u00a0]+|[()\[\]{};,.?\n])/i, ''
      if $2
        tokens << $2
      else
        break
      end
    end
    tokens
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
  methstr = methstr.to_s.gsub( /[<=]*$/, '').sub(/_ids$/, '')
  methstr.singularize.camelize.constantize
end

def escape_newlines str
  str.to_s.gsub(/\n/, '\n')
end

def indent_lines str_or_object, indent="\t"
  str = str_or_object.is_a?(String) ? str : str_or_object.pretty_inspect
  indent = ' '*indent if indent.is_a?(Integer)
  indent+str.split("\n").join("\n"+indent)+"\n"
end

# Recursively write a simple hash to a string
def struct_to_str entity, indent_level=1
  def indent_for_next(level)
    "\n" + "\t"*level
  end
  indent = "\t"*indent_level
  case entity
  when Hash
    lines = entity.keys.collect { |key| indent + (key.is_a?(Symbol) ? ":#{key}" : "\"#{key}\"") + ' => ' + struct_to_str(entity[key], indent_level+1) }
    lines[0..-2].each { |line| line << ',' }
    lines << "#{indent[1..-1]}}"
    "{\n" + lines.join("\n")
  when Array
    lines = entity.collect { |val| indent + struct_to_str(val, indent_level+1) }
    lines[0..-2].each { |line| line << ',' }
    lines << "#{indent[1..-1]}]"
    "[\n" + lines.join("\n")
  when String
    '"' + entity.gsub( /"/, '\"') + '"'
  when Symbol
    ":#{entity}"
  when NilClass
    "nil"
  else
    entity.to_s
  end
end

class String
  # Replace runs of whitespace with a single whitespace character as follows:
  # 1) if the run contains a newline character, replace the run with that
  # 2) if the run contains an &nbsp; character, replace the run with that
  # 3) otherwise, replace it with a space character
  def deflate
    # gsub( /[ \t\n\r\f\v\u00a0]*\n[ \t\n\r\f\v\u00a0]*/, "\n"). # Gaps including a newline convert to newline
    gsub(/\r\n/, "\n"). # Collapse '\r\n' pairs to '\n'
    gsub( /\s*\n\s*/, "\n"). # Gaps including a newline reduce to a single newline
    gsub(/[\u200B\u200C\u200D\uFEFF]/, ' '). # Replace zero-width space characters with space
    gsub( /[ \t\r\f\v\u00a0]*\u00a0[ \t\r\f\v]*/, "\u00a0"). # Gaps including a nonbreaking space reduce to one
    gsub( /[ \t\r\f\v]+/, ' ')  # Gaps including arbitrary whitespace--including the zero-width space character--reduce to single space character
  end
end
