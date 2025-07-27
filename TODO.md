Old compiler output:

```ruby
->(__buffer__) {
  # setup
  __parts__ = [__buffer__.dup]
  __buffer__.clear

  # emit HTML into parts
  __parts__ << "<div>"

  # emit defer block
  __parts__ << ->(__b__) {
    # emit HTML into given buffer 
    __b__ << "<h1>#{CGI.escapeHTML((@foo).to_s)}</h1>"
  }

  # logic
  @foo = 'bar'

  # emit HTML into parts
  __parts__ << "</div>"

  # render parts into buffer
  __parts__.each { |p|
    p.is_a?(Proc) ? p.(__buffer__) : (__buffer__ << p)
  }
}
```

Can we make this any simpler? Can we avoid getting into modes in order to write
to different buffers?

```ruby
->(__buffer__) {
  __buffer__ << "div"

  # !!! setup defer stuff
  __orig_buffer__ = __buffer__; __parts__ = __buffer__ = [];

  # !!! emit defer block
  __buffer__ << ->() {
    # emit HTML
    __buffer__ << "<h1>#{CGI.escapeHTML((@foo).to_s)}</h1>"
  }

  # logic
  @foo = 'bar'

  # emit HTML
  __buffer__ << "</div>"

  # !!! render parts into buffer
  __buffer__ = __orig_buffer__; __parts__.each { it.is_a?(Proc) ? it.() : (__buffer__ << it) }
}
```


## Compiler

- [ ] Finish work on compiler: integrate HTML emission with whitespace
      adjustment mechanism.
- [ ] Add support for all emit possibilities:
      - text
      - emit
      - emit_markdown
      - etc.
- [ ] Add support for special tags: especially html5
- [ ] Add support for defer

## Defer implementation

```ruby
# source
-> {
  scripts = []
  head {
    defer {
      scripts.each {
        script(src: it)
      }
    }
  }
  scripts << 'foo'
}

# compiled
->(__buffer__) {
  scripts = []
  __buffer__ << "<head>"
  
  # prepare defer
    __orig_buffer__ = __buffer__; __defer_parts__ = []; __defer_parts__ << __buffer__; __buffer__.clear
      scripts.each {
        # push defer snippet
        pr = -> { __buffer__<< "<script src==\"#{it}\"></script>"  }
        __parts << pr        
      }
  
  scripts << 'foo'
  
  
  tmp = +''
  __defer_parts__.each do
    case it
    when String
      tmp << it
    when Proc
      __buffer__ = +''
      it.call
      tmp << __buffer__
    end
  end
  __orig_buffer__.clear
  __orig_buffer__ << tmp
}
```

## Enhancements

- [ ] Automatic compilation
- [ ] Once everything's compiled, add support for following:

      ```ruby
      Papercraft.html {
        # class
        p.my_class 'foo' #=> <p class="my-class">foo</p>

        # or maybe
        p.class('my-class') 'foo'

        # or maybe
        p(class: 'my-class') 'foo'

        # or maybe
        p(class: 'my-class') { 'foo' }

        # id
        p['my-id'] 'foo' #=> <p id="my-id">foo</p>
      }
      ```
