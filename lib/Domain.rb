
# Remove the noise from a url to extract the domain
def domain_from_url(url)
	result = url.sub(/https*:\/\//, '') # Eliminate http[s]://
	result.sub!(/^www./, '')	# Eliminate leading 'www'
	result.gsub(/\/.*/, '')	# Eliminate any path after domain
end

# Remove the noise from a url to extract the domain
def path_from_url(url)
	result = url.sub(/https*:\/\/[^\/]*/, '') # Eliminate http[s]:// and beyond to first slash
end

def current_domain
  Rails.env.production? ? "www.recipepower.com" : "localhost:3000" 
end

