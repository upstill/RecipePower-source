class RpMailer < ActionMailer::Base
  default from: "upstill@gmail.com"
  def welcome_email(user)
      @user = user
      @url  = "http://recipepower.com/login"
      mail(:to => user.email, :subject => "Welcome to RecipePower")
    end
end
