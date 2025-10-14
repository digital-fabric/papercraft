<h1 align="center">
  <img src="papercraft.png">
  <br>
  Papercraft
</h1>

<h4 align="center">Functional HTML templating for Ruby</h4>

<p align="center">
  <a href="http://rubygems.org/gems/papercraft">
    <img src="https://badge.fury.io/rb/papercraft.svg" alt="Ruby gem">
  </a>
  <a href="https://github.com/digital-fabric/papercraft/actions/workflows/test.yml">
    <img src="https://github.com/digital-fabric/papercraft/actions/workflows/test.yml/badge.svg" alt="Tests">
  </a>
  <a href="https://github.com/digital-fabric/papercraft/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
  </a>
</p>

```ruby
require 'papercraft'

-> {
  h1 "Hello from Papercraft!"
}.render
#=> "<h1>Hello from Papercraft</h1>"
```

Papercraft is a templating engine for dynamically producing HTML in Ruby apps.
Papercraft templates are expressed as Ruby procs, leading to easier debugging,
better protection against HTML injection attacks, and better code reuse.

Papercraft templates can be composed in a variety of ways, facilitating the
usage of layout templates, and enabling a component-oriented approach to
building web interfaces of arbitrary complexity.

In Papercraft, dynamic data is passed explicitly to the template as block/lambda
arguments, making the data flow easy to follow and understand. Papercraft also
lets developers create derivative templates using full or partial parameter
application.

## Documentation

For more information, please consult the [Papercraft
website](https://papercraft.noteflakes.com/).
