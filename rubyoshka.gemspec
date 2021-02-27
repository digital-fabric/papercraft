require_relative './lib/rubyoshka/version'

Gem::Specification.new do |s|
  s.name        = 'rubyoshka'
  s.version     = Rubyoshka::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'Rubyoshka: composable HTML templating for Ruby'
  s.author      = 'Sharon Rosner'
  s.email       = 'ciconia@gmail.com'
  s.files       = `git ls-files README.md CHANGELOG.md lib`.split
  s.homepage    = 'http://github.com/digital-fabric/rubyoshka'
  s.metadata    = {
    "source_code_uri" => "https://github.com/digital-fabric/rubyoshka"
  }
  s.rdoc_options = ["--title", "rubyoshka", "--main", "README.md"]
  s.extra_rdoc_files = ["README.md"]
  s.require_paths = ["lib"]

  s.add_runtime_dependency      'escape_utils',   '1.2.1'

  s.add_development_dependency  'minitest',       '5.11.3'
  s.add_development_dependency  'benchmark-ips',  '2.7.2'
  s.add_development_dependency  'erubis',         '2.7.0'
  s.add_development_dependency  'tilt',           '2.0.9'
end
