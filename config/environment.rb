# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
RP::Application.initialize!

# Get the encryption key files
# Sentry::AsymmetricSentry.default_public_key_file = "config/publ.key"
# Sentry::AsymmetricSentry.default_private_key_file = "config/priv.key"
