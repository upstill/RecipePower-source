# Methods supporting development of parsing parameters by mirroring data in config files and generating test files
def test_dir
  Rails.root.join 'test', 'sites'
end

# Return the root associated with a site, whether specified as a Site, a String, or the idea of a Site from the database
def site_root site_or_root_or_id
  full =
  case site_or_root_or_id
  when String
    site_or_root_or_id
  when Integer
    Site.find( site_or_root_or_id).root
  when nil
    nil
  else
    site_or_root_or_id.root
  end
  full&.sub /^www./, '' # Elide the leading 'www'
end

def test_file_for site_or_root_or_id, base_only: false
  base = site_root(site_or_root_or_id).gsub('/', '_slash_').gsub( '.', '_dot_')
  base_only ? base : Rails.root.join(test_dir, base+'_test'+'.rb')
end

def config_dir
  Rails.root.join 'config', 'sitedata'
end

def config_file_for site_or_root_or_id
  root = site_root(site_or_root_or_id).gsub('/', '_slash_')
  Rails.root.join config_dir, root + '.yml'
end

# Call a block for each .yml file in the configs/sitedata directory, or a single site as specified
def for_configs site_or_root_or_id=nil
  ymls =
      if site_or_root_or_id
        [ config_file_for(site_or_root_or_id) ]
      else
        Dir.entries( config_dir ).find_all { |fname| fname.match /\.yml$/ }
      end
  ymls.each do |filename|
    filename = config_dir + filename
    if !File.exist? filename
      puts "Error: Can't load YAML file '#{filename}': no such file" if !site_or_root_or_id
      return
    end
    data = YAML.load_file filename
    if !(data && data[:sample_url])
      err = data ? "No :sample_url to be found in YAML" : "YAML failed on"
      puts "ERROR: #{err} file '#{filename}'"
      next
    end
    pr = PageRef.fetch data[:sample_url]
    if site = pr&.site
      yield site, data
    else
      puts "!!! Can't locate site for sample '#{data[:sample_url]}''"
    end
  end
end

