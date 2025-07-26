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
