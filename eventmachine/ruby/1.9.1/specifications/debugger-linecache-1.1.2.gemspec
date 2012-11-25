# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "debugger-linecache"
  s.version = "1.1.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6") if s.respond_to? :required_rubygems_version=
  s.authors = ["R. Bernstein", "Mark Moseley", "Gabriel Horner"]
  s.date = "2012-06-30"
  s.description = "Linecache is a module for reading and caching lines. This may be useful for\nexample in a debugger where the same lines are shown many times.\n"
  s.email = "gabriel.horner@gmail.com"
  s.extensions = ["ext/trace_nums/extconf.rb"]
  s.extra_rdoc_files = ["README.md"]
  s.files = ["README.md", "ext/trace_nums/extconf.rb"]
  s.homepage = "http://github.com/cldwalker/debugger-linecache"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.16"
  s.summary = "Read file with caching"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<debugger-ruby_core_source>, [">= 1.1.1"])
      s.add_development_dependency(%q<rake>, ["~> 0.9.2.2"])
      s.add_development_dependency(%q<rake-compiler>, ["~> 0.8.0"])
    else
      s.add_dependency(%q<debugger-ruby_core_source>, [">= 1.1.1"])
      s.add_dependency(%q<rake>, ["~> 0.9.2.2"])
      s.add_dependency(%q<rake-compiler>, ["~> 0.8.0"])
    end
  else
    s.add_dependency(%q<debugger-ruby_core_source>, [">= 1.1.1"])
    s.add_dependency(%q<rake>, ["~> 0.9.2.2"])
    s.add_dependency(%q<rake-compiler>, ["~> 0.8.0"])
  end
end
