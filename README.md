# castiron – cook with your own *C*ustom _AST_ elements

Define custom pandoc *Block* or *Inline** elements to be used in
Lua scripts; supports filtering and transparent conversion to and
from pandoc's native format.

> [!IMPORTANT]
> This package relies on unpublished pandoc features.
> *Castiron* currently requires a nightly pandoc build.

> [!NOTE]
> This package is developed [on Codeberg][], so this repo might be
> slightly out of date at times. However, please do feel free to
> raise issues or open PRs here on GitHub if you want to, we will
> then merge them back into the main branch.

[on Codeberg]: https://codeberg.org/tarleb/castiron

## Usage

Enable support for custom elements by calling the module's `init`
function.

``` lua
local castiron = require 'castiron'
castiron.init()
```

This will patch pandoc modules and types to make them work with
custom elements.

Each element type must be registered with

``` lua
castiron.define_block_element(MyCustomElementMetatable)
```

where `MyCustomElementMetatable` is the metatable that should be
used for the custom elements. It must have a `__name` string, a
`__toblock` function, and a `__fromblock` filter-like constructor
table.

## Example

Below is the Lua code for the `Example` type.

``` lua
--- Metatable for custom `Example` Block elements
local Example = {}

--- The custom element's name.
Example.__name = 'Example'

--- Creates a string representation
function Example:__tostring ()
  return table.concat{
    'Example {\n',
    '\tcontents = ',
    tostring(self.content),
    '\n}'
  }
end

--- Constructs a new custom element.
function Example:__call(obj)
  local exm = {tag = self.__name, content = obj.content}
  return setmetatable(exm, self)
end

--- Converts the custom element back into a default Block.
function Example:__toblock ()
  return pandoc.Div(self.content, {'', {'Example'}})
end

--- Converters from pandoc Block values in a filter-like structure.
-- Keys must be the tags of standard Block elements, and the values
-- are functions that take the default AST element and return a
-- custom AST element.
Example.__fromblock = {
  Div = function (div)
    if div.classes == List{'Example'} then
      return Example {content = div.content}
    end
  end
}

--- Make Example a metatable of itself so we can use it as
-- a function.
setmetatable(Example, Example)
```

The new Block type is registered with `define_block_element`.

``` lua
castiron.init()
castiron.define_block_element(Example)
```

We can now use the objects of this type like Block elements:

``` lua
local exm = Example{content = pandoc.Blocks('Testing.')}
local blocks = pandoc.Blocks{'other', exm}
local filtered = blocks:walk {
  Example = function (e) --[[ ... ]] end
}
```
