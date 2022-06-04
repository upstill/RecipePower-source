class CSSExtender

  @@SELECTOR = nil

  # Examine a CSS selector string for extensions like regexp support.
  # The return value is an array suitable for splatting into Nokogiri
  # CSS search operators. If there ARE no extensions, the return is
  # a one-element array identical in effect (when splatted) to the original string
  #
  # Extensions are as follows:
  # -- a class or id name may CONSIST IN ITS ENTIRETY of a regular expression delimited by '/'
  # -- otherwise, for syntactic sugar, a class or id name may include '^*$' as follows:
  #     ° '^' anchors the following string at the beginning ("^str" is equivalent to /^str/)
  #     ° '*' is a wildcard character matching any input ("str1*str2" is equivalent to /str1.*str2/)
  #     ° '$' is an anchor character for the end of the string  ("str$" is equivalent to /str$  /)
  def self.args selector
    # We keep a memoized copy of the result for repeated calls
    return @@PROCESSED_ARGS if selector == @@SELECTOR
    classes_and_operands = selector.scan /[.#]|\[[^\]=]+[\]=]|[^.#\[]+/
    # Each "class" BEGINS with a class reference, which is the only class reference in that string.
    # However, it's possible that the '.' was included in a regex, so we may need to collapse
    # elements if the regex extends beyond a given element
    handler = nil
    classes_and_operands.each_index do |class_ix|
      # Skip past 
      next if (class_ix == 0) ||
          !(line = classes_and_operands[class_ix]) ||
          line == '.' ||
          line == '#' ||
          line.first == '['
      attribute_name = nil
      method_name, mod =
          case op = classes_and_operands[class_ix-1].first
          when '.'
            line.match /([\/*$^])/
            ['inclass', $1]
          when '#'
            line.match /([\/*$^])/
            ['inid', $1]
          when '['
            next unless classes_and_operands[class_ix-1].match /\[([^\s>\/'"=]*)=/
            attribute_name = $1
            attribute_name = attribute_name[0..-2] if (mod = attribute_name.last.match(/[~|^$*]$/)&.to_s).present?
            ['regex', (line.first == '/' ? '/' : mod)]
          end
      case mod
      when '/' # A /-delimited regex can follow the specifier
        re = ''
        # Find the end of the regex
        incr = 1
        while !self.valid_regex?(re) do
          substrs = line.scan /\/|[^\/]+/
          while nxt = substrs.shift do
            re << nxt
            break if nxt == '/' && valid_regex?(re)
            if substrs.blank? # End of this line
              # We've run out this "class" without ending the regex.
              # Take input from subsequent lines
              classes_and_operands[class_ix] << (line = classes_and_operands[class_ix + incr])
              classes_and_operands[class_ix + incr] = nil
              incr += 1
            end
          end
        end
        args = "'#{re[1..-2]}'"
        tail = classes_and_operands[class_ix][re.length..-1]
        # Need to delete the closing ']', if any
        if op == '['
          tail.sub! /.*\]/, ''
          args << ", '#{attribute_name}'"
        end
        classes_and_operands[class_ix] = "#{method_name}(#{args})" + tail
        classes_and_operands[class_ix - 1] = ':'
        handler ||= self.new
      else
        if op == '['
          incr = 1
          while !line.match(/((.*)\])/)
            classes_and_operands[class_ix] << (line = classes_and_operands[class_ix + incr])
            classes_and_operands[class_ix + incr] = nil
            incr += 1
          end
          to_replace, value = $1, $2
          if value.match /['"]?([^'"]*)['"]?/  # Elide quotes in the value
            value = $1
            if mod.blank? # Unless a quoted match value has a modifier, just ensure that there are quotes
              classes_and_operands[class_ix] = "\"#{value}\"]" + line[(to_replace.length)..-1]
              next
            end
          end
        else
          line.match /^([\S.#]+)/ # Find the end of the "class" declaration
          to_replace, value = $1, $1
        end
        if mod.present? || value.match(/[$*^]/) # If the string to be matched includes a metacharacter, resort to our methods
          value.gsub! /(^|[^.])\*/, "\\1.*"
          value = '^' + value if mod == '^' && value.first != '^'
          value << '$' if mod == '$' && value.last != '$'
          re = "'" + value + "'"
          re += ", '#{attribute_name}'" if attribute_name
          classes_and_operands[class_ix] = "#{method_name}(#{re})" + line[(to_replace.length)..-1]
          handler ||= self.new
          classes_and_operands[class_ix - 1] = ':'
        end
      end
    end
    @@SELECTOR = selector
    @@PROCESSED_ARGS = [classes_and_operands.compact.join, handler].compact
  end

  def regex(node_set, regex, attribute)
    node_set.find_all { |node| node[attribute] =~ /#{regex}/ }
  end

  # Apply the regex to the classes of a node
  def inclass(node_set, regex)
    node_set.find_all do |node|
      if classes = node['class']
        classes.split.any? { |klass|
          klass =~ /#{regex}/
        }
      end
    end
  end

  # Apply the regex to the classes of a node
  def inid(node_set, regex)
    node_set.find_all do |node|
      (id = node['id']) && (id =~ /#{regex}/)
    end
  end

  def self.valid_regex?(str)
    str[0] == '/' && str[-1] == '/' && (re = str[1..-2]).present? &&
        begin
          Regexp.new(re)
          true
        rescue
          false
        end
  end


end
