require_relative './lib/papercraft/version'

Gem::Specification.new do |s|
  s.name        = 'papercraft'
  s.version     = Papercraft::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'papercraft: composable HTML templating for Ruby'
  s.author      = 'Sharon Rosner'
  s.email       = 'ciconia@gmail.com'
  s.files       = `git ls-files README.md CHANGELOG.md lib`.split
  s.homepage    = 'http://github.com/digital-fabric/papercraft'
  s.metadata    = {
    "source_code_uri" => "https://github.com/digital-fabric/papercraft"
  }
  s.rdoc_options = ["--title", "papercraft", "--main", "README.md"]
  s.extra_rdoc_files = ["README.md"]
  s.require_paths = ["lib"]
  s.required_ruby_version = '>= 2.7'

  s.add_runtime_dependency      'escape_utils',   '1.2.1'

  s.add_development_dependency  'minitest',       '5.11.3'
  s.add_development_dependency  'benchmark-ips',  '2.7.2'
  s.add_development_dependency  'erubis',         '2.7.0'
  s.add_development_dependency  'tilt',           '2.0.9'
end
