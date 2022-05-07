class CSSExtender

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
    classes = selector.split '.'
    # Each "class" BEGINS with a class reference, which is the only class reference in that string.
    # However, it's possible that the '.' was included in a regex, so we may need to collapse
    # elements if the regex extends beyond a given element
    handler = nil
    classes.each_index do |class_ix|
      operand = nil
      next unless (class_ix > 0) && cls = classes[class_ix]
      case chr = cls.first
      when '/'
        re = ''
        # Find the end of the regex
        while !self.valid_regex?(re) do
          substrs = cls.scan /\/|[^\/]+/
          while nxt = substrs.shift do
            re << nxt
            break if nxt == '/' && valid_regex?(re)
            if substrs.blank?  # End of this line
              # We've run out this "class" without ending the regex
              classes[class_ix] << (cls = classes[class_ix+1])
              classes[class_ix+1] = nil
              break
            end
          end
        end
        classes[class_ix] = "inclass('#{re[1..-2]}')" + cls[(re.length)..-1]
        operand = ':'
        handler ||= self.new
      else
        cls.match /^([$*^\w]+)/
        matcher = $1
        operand =
        if matcher.match /[$*^]/
          re = matcher.gsub('*', '.*')
          classes[class_ix] = "inclass('#{re}')" + cls[(matcher.length)..-1]
          handler ||= self.new
          ':'
        else
          '.'
        end
      end
      classes[class_ix] = operand + classes[class_ix] if operand
      operand = '.'
    end
    [classes.compact.join, handler].compact
  end

  def regex(node_set, regex, attribute)
    node_set.find_all { |node| node[attribute] =~ /#{regex}/ }
  end

  # Apply the regex to the classes of a node
  def inclass(node_set, regex)
    node_set.find_all do |node|
      if classes = node['class']
        classes.split.any? { |cls|
          cls =~ /#{regex}/
        }
      end
    end
  end

  def self.valid_regex?(str)
    str[1] &&
        begin
          Regexp.new(str)
          true
        rescue
          false
        end
  end


end
