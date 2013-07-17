# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'couchdb_backup/version'

Gem::Specification.new do |gem|
  gem.name          = "couchdb_backup"
  gem.version       = CouchdbBackup::VERSION
  gem.description   = %q{Backup CouchDB databases to AWS S3}
  gem.summary       = %q{Backup CouchDB data directory to Amazon Web Services S3}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  # Dependencies
  gem.add_runtime_dependency "thor"
  gem.add_runtime_dependency "couchrest"
  gem.add_runtime_dependency "zip"

  gem.add_development_dependency "rspec"
end
