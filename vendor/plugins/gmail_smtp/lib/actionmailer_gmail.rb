=begin
ActionMailer::Base.smtp_settings = {
	:address => "smtp.gmail.com",
	:port => 587,
	:authentication => :plain,
	:domain => ENV['GMAIL_SMTP_USER'],
	:user_name => ENV['GMAIL_SMTP_USER'],
	:password => ENV['GMAIL_SMTP_PASSWORD'],
}
=end
ActionMailer::Base.smtp_settings = {
  :address        => ENV['MAILGUN_SMTP_SERVER'],
  :port           => ENV['MAILGUN_SMTP_PORT'], 
  :authentication => :plain,
  :domain         => 'strong-galaxy-5765.heroku.com',
  :user_name      => ENV['MAILGUN_SMTP_LOGIN'],
  :password       => ENV['MAILGUN_SMTP_PASSWORD'],
}
# ActionMailer::Base.delivery_method = :smtp