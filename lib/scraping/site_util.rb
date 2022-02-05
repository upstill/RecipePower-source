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
    Site.find(site_or_root_or_id).root
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

# Fetch a site based on the root, meanwhile confirming that the given sample leads to that site
def confirm_site root, sample_url
  pr = PageRef.fetch sample_url
  if !(site = pr&.site)
    raise "Can't locate site for sample '#{sample_url}'"
  elsif !root ||
      !(rootsite = Site.find_by(root: root) || Site.find_by(root: 'www.'+root))
    raise "No site associated with root '#{root || 'nil'}'"
  elsif (rootsite != site) # The site from the sample url is not the same as the site with the root
    raise "Site ##{site.id} associated with sample '#{sample_url}' is not the same as site #{rootsite.id} with root '#{rootsite.root}'"
  end
  site
end

# Call a block for each .yml file in the configs/sitedata directory, or a single site as specified
# Optionally (and by default) fetch the associated site(s) from the database
# Call a block with each site and its configs
def for_configs site_or_root_or_id=nil, fetch_site: true
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
    if !(data && (sample_url = data[:sample_url]))
      err = data ? "No :sample_url to be found in YAML" : "YAML failed on"
      raise "ERROR: #{err} file '#{filename}'"
      next
    end
    site = confirm_site(data[:root], sample_url) if fetch_site
    yield site, data
  end
end

