# Remove the noise from a url to extract the domain
def domain_from_url(url)
  result = url.sub(/https*:\/\//, '') # Eliminate http[s]://
  result.sub!(/^www./, '') # Eliminate leading 'www'
  result.gsub(/\/.*/, '') # Eliminate any path after domain
end

# Remove the noise from a url to extract the domain
def path_from_url(url)
  result = url.sub(/https*:\/\/[^\/]*/, '') # Eliminate http[s]:// and beyond to first slash
end

# Provide a url based on the current environment
def rp_url path=''
  case
    when Rails.env.production?
      'https://www.recipepower.com'
    when Rails.env.development?, Rails.env.test?
      'https://local.recipepower.com:3000'
    when Rails.env.staging?
      'https://staging.recipepower.com'
  end + path.to_s
end

# We don't record urls from any of our hosts
def host_forbidden url
  uri = URI url
  ["recipepower.com",
   "www.recipepower.com",
   "local.recipepower.com",
   "staging.herokuapp.com"].include? uri.host
end

=begin
def current_domain
  case
    when Rails.env.production?
      "www.recipepower.com"
    when Rails.env.development?, Rails.env.test?
      "local.recipepower.com:3000"
    when Rails.env.staging?
      "staging.herokuapp.com"
  end
end
=end

