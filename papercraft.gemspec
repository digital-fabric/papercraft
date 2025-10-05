require_relative './lib/papercraft/version'

Gem::Specification.new do |s|
  s.name        = 'papercraft'
  s.version     = Papercraft::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'Papercraft: functional HTML templating for Ruby'
  s.author      = 'Sharon Rosner'
  s.email       = 'sharon@noteflakes.com'
  s.files       = `git ls-files README.md CHANGELOG.md lib`.split
  s.homepage    = 'http://github.com/digital-fabric/papercraft'
  s.metadata    = {
    "homepage_uri" => "https://github.com/digital-fabric/papercraft",
    "documentation_uri" => "https://www.rubydoc.info/gems/papercraft",
    "changelog_uri" => "https://github.com/digital-fabric/papercraft/blob/master/CHANGELOG.md"
  }

  s.rdoc_options = ["--title", "Papercraft", "--main", "README.md"]
  s.extra_rdoc_files = ["README.md", "papercraft.png"]
  s.require_paths = ["lib"]
  s.required_ruby_version = '>= 3.4'

  s.add_runtime_dependency      'sirop',                '~>0.9'
  s.add_runtime_dependency      'kramdown',             '~>2.5.1'
  s.add_runtime_dependency      'rouge',                '~>4.6.1'
  s.add_runtime_dependency      'kramdown-parser-gfm',  '~>1.1.0'

  s.add_development_dependency  'minitest',             '~>5.25.5'
  s.add_development_dependency  'benchmark-ips',        '~>2.14.0'
end
