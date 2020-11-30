class Result
  include ActiveModel::Serialization

  attr_accessor :finderdata, :out

  def initialize(f=nil)
    @finderdata = f&.attributes_hash
    @out = []
  end

  # Extract the data from a node under the given label
  # If append is true, just add the string to the existing string
  def push str_in, append = false
    unless str_in.nil?
      begin
        # Somehow, str_in can be a URI, so need to ensure it's a string
        str_out = str_in.to_s.
            # encode('ASCII-8BIT', 'binary', :invalid => :replace, :undef => :replace).
            encode('UTF-8').gsub(/ ,/, ',')
      rescue Exception => e
        logger.debug "STRING ENCODING ERROR on #{str_in}"
        str_out = str_in.to_s.encode('ASCII-8BIT', 'binary', :invalid => :replace, :undef => :replace)
      end
    end
    unless str_out.blank?
      # Add to result
      if append
        self.out[0] = "#{out[0]}#{str_out}"
      else
        self.out << str_out unless out.include?(str_out) # Add to the list of results
      end
    end
  end

  def found
    out.join('').length > 0
  end

  def report
=begin
    puts '------------------------------------------'
    puts "...results due to Finder #{@finderdata.slice :id, :label, :selector, :attribute_name, :site_id}:"
    puts "\t"+out[0..10].collect { |line| line.truncate(200) }.join("\n\t")
=end
  end

  def is_for(label)
    @finderdata[:label] == label
  end

  def glean_atag matchstr, atag, site_home
    if href = atag.attribute('href')
      uri = href.value
      uri = safe_uri_join(site_home, uri) if uri =~ /^\// # Prepend domain/site to path as nec.
      outstr = atag.content
      if uri =~ /#{matchstr}/ # Apply subsite constraint
        push outstr
        push '\t'+uri, true unless uri.blank?
      end
    end
  end

  # Dump self into a YAML string for the Finder's id and the results array
  def self.dump result
    dumped = { out: result.out }
    if fd = result.finderdata
      finder_id = fd[:id]
      unless Finder.exists?(id: finder_id)
        site = fd[:site] || Site.find_by(id: fd[:site_id])
        finder = Finder.create fd.slice(:label, :selector, :attribute_name).merge(site: site)
        finder_id = finder.id
      end
      dumped[:finder_id] = finder_id
    end
    dumped.to_yaml
  end

  # Un-serialize a string
  def self.load str
    hashvals = YAML.load str
    result = self.new Finder.find_by(id: hashvals[:finder_id])
    result.out = hashvals[:out]
    result
  end

end
