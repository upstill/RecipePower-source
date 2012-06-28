Rails.application.config.middleware.use OmniAuth::Builder do
    provider :twitter, ENV['TWITTER_ID'], ENV['TWITTER_SECRET']
    provider :facebook, ENV['FACEBOOK_ID'], ENV['FACEBOOK_SECRET']
    provider :google_oauth2, ENV['GOOGLE_ID'], ENV['GOOGLE_SECRET'], {access_type: 'online', approval_prompt: ''}
end