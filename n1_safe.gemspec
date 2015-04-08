$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "n1_safe/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "n1_safe"
  s.version     = N1Safe::VERSION
  s.authors     = ["tompng"]
  s.email       = ["tomoyapenguin@gmail.com"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of N1Safe."
  s.description = "TODO: Description of N1Safe."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.1"

  s.add_development_dependency "sqlite3"
end
