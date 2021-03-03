- Add `#script` method that takes verbatim JS code:

  ```ruby
  H {
    style <<~EOF
      var todos = $('#js-todos');
      console.log(todos);
    EOF
  }
  ```

- Add '#style' method that takes verbatim CSS:


  ```ruby
  H {
    style <<~CSS
      main {
        color: magenta;
        padding: 0.5em;
      }
    CSS
  }
  ```

- Add `H#set_id` method for setting id for the outer tag of an HTML snippet or
  component
- Add `H.each` method that takes a list, applies the block to each item, and
  sets the id for the block's result to the item's hash in base 36
  `html.set_id(i.hash.to_s(36))`
