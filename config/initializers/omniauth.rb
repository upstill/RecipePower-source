Rails.application.config.middleware.use OmniAuth::Builder do
    provider :twitter, ENV['TWITTER_ID'], ENV['TWITTER_SECRET']
    provider :facebook, ENV['FACEBOOK_ID'], ENV['FACEBOOK_SECRET']
    provider :google_oauth2, ENV['GOOGLE_ID'], ENV['GOOGLE_SECRET'], {access_type: 'online', approval_prompt: ''}
    
end

OmniAuth.config.on_failure do |env|
  exception = env['omniauth.error']
  error_type = env['omniauth.error.type']
  strategy = env['omniauth.error.strategy']
debugger
  Rails.logger.error("OmniAuth Error (#{error_type}): #{exception.inspect}")
  # ErrorNotifier.exception(exception, :strategy => strategy.inspect, :error_type => error_type)

  new_path = "#{env['SCRIPT_NAME']}#{OmniAuth.config.path_prefix}/failure?message=#{error_type}"

  [302, {'Location' => new_path, 'Content-Type'=> 'text/html'}, []]
end
