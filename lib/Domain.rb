
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
  case
  when Rails.env.production?
    "www.recipepower.com"
  when Rails.env.development?, Rails.env.test?
    "local.recipepower.com:3000" 
  when Rails.env.staging?
    "strong-galaxy-5765-74.herokuapp.com"
  end
end

