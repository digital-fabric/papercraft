## Add missing escaping of attribute values:

https://html.spec.whatwg.org/multipage/parsing.html#serialising-html-fragments

- Replace any occurrence of the "&" character by the string "&amp;".
- Replace any occurrences of the U+00A0 NO-BREAK SPACE character by the string "&nbsp;".
- Replace any occurrences of the "<" character by the string "&lt;".
- Replace any occurrences of the ">" character by the string "&gt;".
- If the algorithm was invoked in the attribute mode, then replace any occurrences of the """ character by the string "&quot;".

## API

- [ ] Support for inlining (needed for doing extension procs - see below)

      - [ ] Detect procs that can be inlined by interrogating the original
            proc's binding:

            ```ruby
            # for local variable:
            o.binding.local_variable_defined?(:foo)
            o.binding.local_variable_get(:foo)

            # for const
            o.binding.eval('Foo')
            ```

      - [ ] Detect whether proc can be inlined:

            - No local var assignments
            - No return statements

      - [ ] Reimplement source map generation such that it can include entries
            pointing to different files
