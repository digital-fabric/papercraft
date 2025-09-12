# frozen_string_literal: true

task :default => :test
task :test do
  exec 'ruby test/run.rb'
end

task :release do
  require_relative './lib/papercraft/version'
  version = Papercraft::VERSION

  puts 'Building papercraft...'
  `gem build papercraft.gemspec`

  puts "Pushing papercraft #{version}..."
  `gem push papercraft-#{version}.gem`

  puts "Cleaning up..."
  `rm *.gem`
end
