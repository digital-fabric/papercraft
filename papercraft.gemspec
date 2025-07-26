require_relative './lib/papercraft/version'

Gem::Specification.new do |s|
  s.name        = 'papercraft'
  s.version     = Papercraft::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'Papercraft: component-based HTML templating for Ruby'
  s.author      = 'Sharon Rosner'
  s.email       = 'sharon@noteflakes.com'
  s.files       = `git ls-files README.md CHANGELOG.md lib`.split
  s.homepage    = 'http://github.com/digital-fabric/papercraft'
  s.metadata    = {
    "source_code_uri" => "https://github.com/digital-fabric/papercraft",
    "documentation_uri" => "https://www.rubydoc.info/gems/papercraft",
    "homepage_uri" => "https://github.com/digital-fabric/papercraft",
    "changelog_uri" => "https://github.com/digital-fabric/papercraft/blob/master/CHANGELOG.md"
  }

  s.rdoc_options = ["--title", "Papercraft", "--main", "README.md"]
  s.extra_rdoc_files = ["README.md", "papercraft.png"]
  s.require_paths = ["lib"]
  s.required_ruby_version = '>= 3.4'

  s.add_runtime_dependency      'sirop',                '~>0.7'
  s.add_runtime_dependency      'escape_utils',         '~>1.3.0'
  s.add_runtime_dependency      'kramdown',             '~>2.5.1'
  s.add_runtime_dependency      'rouge',                '~>4.5.1'
  s.add_runtime_dependency      'kramdown-parser-gfm',  '~>1.1.0'

  s.add_development_dependency  'minitest',             '~>5.25.4'
  s.add_development_dependency  'benchmark-ips',        '~>2.7.2'
  s.add_development_dependency  'erubis',               '~>2.7.0'
  s.add_development_dependency  'tilt',                 '~>2.2.0'
end
