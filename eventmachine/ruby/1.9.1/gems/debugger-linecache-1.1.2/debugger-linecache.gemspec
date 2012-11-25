# -*- encoding: utf-8 -*-
require 'rubygems' unless defined? Gem
require File.dirname(__FILE__) + "/lib/debugger/linecache"

Gem::Specification.new do |s|
  s.name = "debugger-linecache"
  s.version = Debugger::Linecache::VERSION
  s.authors = ["R. Bernstein", "Mark Moseley", "Gabriel Horner"]
  s.email = "gabriel.horner@gmail.com"
  s.homepage = "http://github.com/cldwalker/debugger-linecache"
  s.summary = %q{Read file with caching}
  s.description = %q{Linecache is a module for reading and caching lines. This may be useful for
example in a debugger where the same lines are shown many times.
}
  s.required_rubygems_version = ">= 1.3.6"
  s.extra_rdoc_files = ["README.md"]
  s.files = `git ls-files`.split("\n")
  s.extensions << "ext/trace_nums/extconf.rb"
  s.add_dependency "debugger-ruby_core_source", '>= 1.1.1'
  s.add_development_dependency 'rake', '~> 0.9.2.2'
  s.add_development_dependency 'rake-compiler', '~> 0.8.0'
end
