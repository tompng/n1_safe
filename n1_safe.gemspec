$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "n1_safe/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "n1_safe"
  s.version     = N1Safe::VERSION
  s.authors     = ["tompng"]
  s.email       = ["tomoyapenguin@gmail.com"]
  s.summary     = "N+1 Query Safe"
  s.license     = "MIT"

  s.files = Dir["lib/**/*"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails"

  s.add_development_dependency "sqlite3"
end
