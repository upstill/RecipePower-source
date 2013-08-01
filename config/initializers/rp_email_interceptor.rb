require './lib/rp_email_interceptor'

ActionMailer::Base.register_interceptor(RpEmailInterceptor)