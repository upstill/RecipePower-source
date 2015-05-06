# web: bundle exec unicorn -p $PORT -E $RACK_ENV -c config/unicorn.rb
web: bundle exec thin start --ssl --ssl-key-file server.key --ssl-cert-file server.crt
# worker:  bundle exec rake jobs:work
