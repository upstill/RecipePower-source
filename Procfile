web: bundle exec rails server unicorn -p $PORT -e $RACK_ENV -c config/unicorn.rb
worker:  bundle exec rake jobs:work