- Add `H#set_id` method for setting id for the outer tag of an HTML snippet or
  component
- Add `H.each` method that takes a list, applies the block to each item, and
  sets the id for the block's result to the item's hash in base 36
  `html.set_id(i.hash.to_s(36))`
