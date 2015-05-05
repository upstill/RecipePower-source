# web: bundle exec unicorn -p $PORT -E $RACK_ENV -c config/unicorn.rb
web: thin start --ssl --ssl-key-file ~/.ssl/server.key --ssl-cert-file ~/.ssl/server.crt
worker:  bundle exec rake jobs:work