# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "findler/version"

Gem::Specification.new do |s|
  s.name = "findler"
  s.version = Findler::VERSION
  s.authors = ["Matthew McEachen"]
  s.email = ["matthew+github@mceachen.org"]
  s.homepage = "https://github.com/mceachen/findler/"
  s.summary = %q{Findler is a stateful filesystem iterator}
  s.description = %q{Findler is designed for very large filesystem hierarchies,
  where simple block processing, or returning an array of matches, just isn't feasible.
  Usage instructions are available in the README.}

  s.rubyforge_project = "findler"

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_development_dependency "rake"
  s.add_development_dependency "yard"
  s.add_development_dependency "rspec", "~> 2.7.0"
  s.add_dependency "bloomer"
end
