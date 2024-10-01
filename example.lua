local pandoc = require 'pandoc'
local List   = require 'pandoc.List'

local example_private = List{}

local example_element_mt = {
  __name = 'Example',
  __tostring = function (t)
    return table.concat{
      'Example {',
      '\n  attr:    ',
      tostring(t.attr),
      ',\n  public:  ',
      tostring(t.public),
      ',\n  private: ',
      tostring(t.private or List{}),
      ',\n}'
    }
  end,
  __toblock = function (t)
    local private_id
    if t.private then
      example_private:insert(t.private)
      private_id = tostring(#example_private)
    end
    local attr = t.attr and t.attr:clone() or pandoc.Attr()
    attr.classes = List{'Example'}
    attr.attributes['custom-element-placeholder'] = private_id
    return pandoc.Div(t.public, attr)
  end,
  __index = function (t, idx)
    return debug.getuservalue(t, 1)[idx]
  end,
  __newindex = function (t, idx, v)
    debug.getuservalue(t, 1)[idx] = v
  end
}

local function Example (o)
  o.t = 'Example'
  o.private = pandoc.Blocks(o.private)
  o.public = pandoc.Blocks(o.public)
  o.attr = o.attr or pandoc.Attr()
  return setmetatable(o, example_element_mt)
end

example_from_block = {
  Div = function (div)
    if div.classes == List{'Example'} then
      local private_id = div.attr.attributes['custom-element-placeholder']
      local private
      if private_id then
        local i = tonumber(private_id)
        private = example_private:remove(i)
      end
      local obj = {
        tag = 'Example',
        public = div.content,
        private = private,
        attr = div.attr,
      }
      return obj, example_element_mt
    end
  end
}

pretty = function (x)
  print(pandoc.write(pandoc.Pandoc(x), 'native'))
end

------------------------------------------------------------------------

expl = Example{
  tag = 'Example',
  public  = pandoc.CodeBlock('This *should* be filtered'),
  private = pandoc.CodeBlock('This should not be filtered!'),
  attr = pandoc.Attr(),
}

print(expl)

blocks = pandoc.Blocks{expl}

filter = {
  Div = function (div)
    div.classes:insert('filtered')
    return div
  end,
  CodeBlock = function (cb)
    cb.classes:insert('filtered')
    return cb
  end,
}

filter_on_example = {
  Example = print,
}

print(blocks[1])
print(blocks:walk(filter)[1])

local custom = require 'custom-elements'
custom.init()
custom.define_block_element('Example', example_from_block)

print(blocks[1])
print(blocks:walk(filter)[1])
