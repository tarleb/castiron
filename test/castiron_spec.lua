local castiron = require 'castiron'
local pandoc   = require 'pandoc'
local List     = require 'pandoc.List'

castiron.init()

local Example = {}
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
  local exm = {tag = self.__name, content = obj.content}
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
    assert.is_false(seen)
    assert.are_same(blks, result)
  end)

  it('filtering non-custom Blocks still works', function ()
    local exm = pandoc.Div('test')
    local seen = false
    local filter = {Div = function () seen = true end}
    pandoc.Blocks{'plant', exm}:walk(filter)
    assert.is_true(seen)
  end)

  it('allows to filter custom elements', function ()
    local exm = pandoc.Div('test', {'', {'Example'}})
    local seen = false
    local filter = {Example = function () seen = true end}
    pandoc.Blocks{'plant', exm}:walk(filter)
    assert.is_true(seen)
  end)
end)
