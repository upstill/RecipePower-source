class Result
  include ActiveModel::Serialization

  attr_accessor :finderdata, :out

  def initialize(f=nil)
    @finderdata = f && f.attributes_hash
    @out = []
  end

  # Extract the data from a node under the given label
  def push (str_in, uri=nil)
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
      str_out << '\t'+uri unless uri.blank?
      self.out << str_out unless out.include?(str_out) # Add to the list of results
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
      push outstr, uri if uri =~ /#{matchstr}/ # Apply subsite constraint
    end
  end

  # Dump self into a YAML string for the Finder's id and the results array
  def self.dump result
    finder_id = result.finderdata[:id]
    unless Finder.exists?(id: finder_id)
      site = result.finderdata[:site] || Site.find_by(id: result.finderdata[:site_id])
      finder = Finder.create result.finderdata.slice(:label, :selector, :attribute_name).merge(site: site)
      finder_id = finder.id
    end
    {:finder_id => finder_id, :out => result.out}.to_yaml
  end

  # Un-serialize a string
  def self.load str
    hashvals = YAML.load str
    result = self.new Finder.find(hashvals[:finder_id])
    result.out = hashvals[:out]
    result
  end

end
