class Result

  attr_accessor :finderdata, :out

  def initialize(f=nil)
    @finderdata = f && f.attributes_hash
    @out = []
  end

  # Extract the data from a node under the given label
  def push (str_in, uri=nil)
    unless str_in.nil?
      begin
        str_out = str_in.
            # encode('ASCII-8BIT', 'binary', :invalid => :replace, :undef => :replace).
            encode('UTF-8').gsub(/ ,/, ',')
      rescue Exception => e
        logger.debug "STRING ENCODING ERROR on #{str_in}"
        str_out = str_in.encode('ASCII-8BIT', 'binary', :invalid => :replace, :undef => :replace)
      end
    end
    unless str_out.blank?
      # Add to result
      str_out << '\t'+uri unless uri.blank?
      self.out << str_out # Add to the list of results
    end
  end

  def found
    out.join('').length > 0
  end

  def report
    puts "...results due to #{@finderdata}:"
    puts "\t"+out.join("\n\t")
  end

  def is_for(label)
    @finderdata[:label] == label
  end

  def glean_atag matchstr, atag, site_home
    if href = atag.attribute('href')
      uri = href.value
      uri = URI.join(site_home, uri) if uri =~ /^\// # Prepend domain/site to path as nec.
      outstr = atag.content
      push outstr, uri if uri =~ /#{matchstr}/ # Apply subsite constraint
    end
  end

end
