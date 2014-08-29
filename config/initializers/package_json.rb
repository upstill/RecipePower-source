class PackageJson
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)
      # response.body << "..." WILL NOT WORK
      [status, headers, response]
    end
end