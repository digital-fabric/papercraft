# frozen_string_literal: true

task :default => :test
task :test do
  exec 'ruby test/run.rb'
end

task :release do
  require_relative './lib/p2/version'
  version = P2::VERSION

  puts 'Building p2...'
  `gem build p2.gemspec`

  puts "Pushing p2 #{version}..."
  `gem push p2-#{version}.gem`

  puts "Cleaning up..."
  `rm *.gem`
end
