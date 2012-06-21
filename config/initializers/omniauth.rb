Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter, 'SvRXtEuYyIXvUWouhDSvQ', 'QhQrvVn0e94kkdQFoVhW8veW1kcios5ZbwTSLcatg'
  provider :facebook, '432441350110123', 'bf82660d3944f7b64da3a4f08d437f4a'
end