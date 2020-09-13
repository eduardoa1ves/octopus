# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "octopus/version"

Gem::Specification.new do |s|
  s.name        = "ar-octopus"
  s.version     = Octopus::VERSION
  s.authors     = ["Thiago Pradi", "Mike Perham", "Gabriel Sobrinho"]
  s.email       = ["tchandy@gmail.com", "mperham@gmail.com", "gabriel.sobrinho@gmail.com"]
  s.homepage    = "https://github.com/tchandy/octopus"
  s.summary     = %q{Easy Database Sharding for ActiveRecord}
  s.description = %q{This gem allows you to use sharded databases with ActiveRecord. This also provides a interface for replication and for running migrations with multiples shards.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.post_install_message = "Important: If you are upgrading from < Octopus 0.5.0 you need to run:\n" \
                           "$ rake octopus:copy_schema_versions\n\n" \
                           "Octopus now stores schema version information in each shard and migrations will not " \
                           "work properly unless this task is invoked."

  s.add_dependency 'activerecord', '>= 2.3.0'
  s.add_dependency 'activesupport', '>= 2.3.0'
  s.add_development_dependency 'rake', '>= 0.8.7'
  s.add_development_dependency 'rspec', '>= 2.0.0'
  s.add_development_dependency 'mysql', '2.8.1'
  s.add_development_dependency 'pg', '>= 0.11.0'
  s.add_development_dependency 'sqlite3', '>= 1.3.4'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'appraisal', '>= 0.3.8'
end
