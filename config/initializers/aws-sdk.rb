Rails.logger.debug "Initializing S3 bucket #{ENV['S3_BUCKET']} with key=#{(ENV['AWS_ACCESS_KEY_ID'] || '').truncate 6}, secret=#{(ENV['AWS_SECRET_ACCESS_KEY'] || '').truncate 6}"
AWS.config access_key_id:     ENV['AWS_ACCESS_KEY_ID'],
           secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
S3_BUCKET = AWS::S3.new.buckets[ENV['S3_BUCKET']]