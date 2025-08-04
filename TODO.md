## Reimplement





## Compiler

- [v] Finish work on compiler: integrate HTML emission with whitespace
      adjustment mechanism.
- [v] Add support for all emit possibilities:
      - text
      - emit
      - emit_markdown
      - etc.
- [v] 
- [v] Add support for special tags: especially html5
- [v] Add support for defer
- [ ] Make compiled proc return the buffer
- [ ] Add support for inlining emitted sub-templates
- [ ] Add support for emit_yield?



## Enhancements

- [ ] Behind the scenes compile every 


- [ ] Automatic compilation
- [ ] Once everything's compiled, add support for following:

      ```ruby
      P2.html {
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

