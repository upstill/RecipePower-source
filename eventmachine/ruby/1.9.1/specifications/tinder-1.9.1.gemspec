# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "tinder"
  s.version = "1.9.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6") if s.respond_to? :required_rubygems_version=
  s.authors = ["Brandon Keepers", "Brian Ryckbost"]
  s.date = "2012-09-07"
  s.description = "A Ruby API for interfacing with Campfire, the 37Signals chat application."
  s.email = ["brandon@opensoul.org", "bryckbost@gmail.com"]
  s.extra_rdoc_files = ["README.markdown"]
  s.files = ["README.markdown"]
  s.homepage = "http://github.com/collectiveidea/tinder"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.16"
  s.summary = "Ruby wrapper for the Campfire API"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<eventmachine>, ["< 2", ">= 0.12.0"])
      s.add_runtime_dependency(%q<faraday>, ["~> 0.8"])
      s.add_runtime_dependency(%q<faraday_middleware>, ["~> 0.8"])
      s.add_runtime_dependency(%q<hashie>, ["~> 1.0"])
      s.add_runtime_dependency(%q<json>, ["~> 1.6"])
      s.add_runtime_dependency(%q<mime-types>, ["~> 1.16"])
      s.add_runtime_dependency(%q<multi_json>, ["~> 1.0"])
      s.add_runtime_dependency(%q<multipart-post>, ["~> 1.1"])
      s.add_runtime_dependency(%q<twitter-stream>, ["~> 0.1"])
      s.add_development_dependency(%q<fakeweb>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
    else
      s.add_dependency(%q<eventmachine>, ["< 2", ">= 0.12.0"])
      s.add_dependency(%q<faraday>, ["~> 0.8"])
      s.add_dependency(%q<faraday_middleware>, ["~> 0.8"])
      s.add_dependency(%q<hashie>, ["~> 1.0"])
      s.add_dependency(%q<json>, ["~> 1.6"])
      s.add_dependency(%q<mime-types>, ["~> 1.16"])
      s.add_dependency(%q<multi_json>, ["~> 1.0"])
      s.add_dependency(%q<multipart-post>, ["~> 1.1"])
      s.add_dependency(%q<twitter-stream>, ["~> 0.1"])
      s.add_dependency(%q<fakeweb>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 0"])
    end
  else
    s.add_dependency(%q<eventmachine>, ["< 2", ">= 0.12.0"])
    s.add_dependency(%q<faraday>, ["~> 0.8"])
    s.add_dependency(%q<faraday_middleware>, ["~> 0.8"])
    s.add_dependency(%q<hashie>, ["~> 1.0"])
    s.add_dependency(%q<json>, ["~> 1.6"])
    s.add_dependency(%q<mime-types>, ["~> 1.16"])
    s.add_dependency(%q<multi_json>, ["~> 1.0"])
    s.add_dependency(%q<multipart-post>, ["~> 1.1"])
    s.add_dependency(%q<twitter-stream>, ["~> 0.1"])
    s.add_dependency(%q<fakeweb>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 0"])
  end
end
