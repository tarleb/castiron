local castiron = require 'castiron'
local pandoc   = require 'pandoc'
local List     = require 'pandoc.List'

castiron.init()

local Example = {tag = 'Example'}
Example.__index = Example
Example.__name = 'Example'
function Example:__tostring ()
  return table.concat{
    'Example {\n',
    '\tcontents = ',
    tostring(self.content),
    '\n}'
  }
end
function Example:__toblock ()
  return pandoc.Div(self.content, {'', {'Example'}})
end
function Example:__call(obj)
  local exm = {content = obj.content}
  return setmetatable(exm, self)
end
Example.__fromblock = {
  Div = function (div)
    if div.classes == List{'Example'} then
      return Example {content = div.content}
    end
  end
}
setmetatable(Example, Example)

castiron.define_block_element(Example)

describe('castiron', function ()
  it('converts block elements to custom elements when appropriate', function ()
    local exm = pandoc.Div('test', {'', {'Example'}})
    assert.is_equal('Example', exm.tag)
  end)

  it('filtering on the encoding Block ignores the custom', function ()
    local exm = pandoc.Div('test', {'', {'Example'}})
    local seen = false
    local filter = {Div = function () seen = true end}
    local blks   = pandoc.Blocks{'plant', exm}
    local result = blks:walk(filter)
    assert.is_falsy(seen)
    assert.are_same(blks, result)
  end)
end)
