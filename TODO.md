## Next: fold into Papercraft

- Publish as Papercraft, remove Papercraft repo, gem

## Add missing escaping of attribute values:

https://stackoverflow.com/questions/9187946/escaping-inside-html-tag-attribute-value

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
