## Immediate

- Refactor proc_ext:
  - remove all methods except for `render`, `apply`, `render_cache` from Proc.
  - put them under `Papercraft` module.
- Rework `render_cache` to take a key (instead of computing it from args).

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
