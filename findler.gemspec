# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "findler/version"

Gem::Specification.new do |gem|
  gem.name = "findler"
  gem.version = Findler::VERSION
  gem.authors = ["Matthew McEachen"]
  gem.email = ["matthew+github@mceachen.org"]
  gem.homepage = "https://github.com/mceachen/findler/"
  gem.summary = %q{Findler is a stateful filesystem iterator}
  gem.description = %q{Findler is designed for very large filesystem hierarchies,
  where simple block processing, or returning an array of matches, just isn't feasible.
  Usage instructions are available in the README.}

  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- {test,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  gem.require_paths = ["lib"]
  gem.add_development_dependency "rake"
  gem.add_development_dependency "yard"
  gem.add_development_dependency "minitest"
  gem.add_dependency "bloomer"
end
