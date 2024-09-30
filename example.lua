local pandoc = require 'pandoc'
local custom = require 'custom-elements'
local List   = require 'pandoc.List'

custom.init()

local example_element_mt = {
  __name = 'Example',
  __tostring = function (t)
    return table.concat{
      'Example ',
      tostring(t.public)
    }
  end,
  __toblock = function (t)
    return pandoc.Div(
      t.public,
      {['custom-element-placeholder'] = nil}
    )
  end,
  __index = function (t, idx)
    return debug.getuservalue(t, 1)[idx]
  end
}

local example_from_block = {
  Div = function (div)
    if div.classes == List{'Example'} then
      return {tag = 'Example', public = div.content}, example_element_mt
    end
  end
}

custom.define_block_element('Example', example_from_block)

local expl = (pandoc.Div('Bonjour!', {class='Example'}))

print(expl)


