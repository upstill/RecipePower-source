# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "closure_tree"
  s.version = "3.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Matthew McEachen"]
  s.date = "2011-11-27"
  s.description = "    A mostly-API-compatible replacement for the acts_as_tree and awesome_nested_set gems,\n    but with much better mutation performance thanks to the Closure Tree storage algorithm\n"
  s.email = ["matthew-github@mceachen.org"]
  s.homepage = "http://matthew.mceachen.us/closure_tree"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.16"
  s.summary = "Hierarchies for ActiveRecord models using a Closure Tree storage algorithm"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activerecord>, [">= 3.0.0"])
    else
      s.add_dependency(%q<activerecord>, [">= 3.0.0"])
    end
  else
    s.add_dependency(%q<activerecord>, [">= 3.0.0"])
  end
end
