local pandoc = require 'pandoc'
local debug = require 'debug'

local M = {}

local custom_block_types = {}
local custom_from_block = {}

function M.define_block_element (name, fromblock, toblock)
  for tag, fn in pairs(fromblock) do
    custom_from_block[tag] = custom_from_block[tag] or pandoc.List()
    custom_from_block[tag]:insert(fn)
  end
  -- custom_block_types[name] = custom_element_type
end

local function make_new_metamethod (metatable, method_name)
  local orig_method = metatable[method_name]

  local function metamethod (t, ...)
    -- Check if the object already has a caching table
    if debug.getuservalue(t, 1) then
      -- Has a table. Keep as is.
      return orig_method(t, ...)
    else
      -- Doesn't have a caching table yet. Check if it's a
      -- "pandocized" custom element.
      local tag = metatable.getters.tag(t)
      -- set caching table, as `t` should now behave like a normal block
      debug.setuservalue(t, {tag = tag}, 1)
      local newtable, newmetatable
      for _, fn in ipairs(custom_from_block[tag] or {}) do
        newtable, newmetatable = fn(t)
        if newtable then
          break
        end
      end
      if newtable then
        -- set alternative type
        debug.setuservalue(t, newtable, 1)
        debug.setmetatable(t, newmetatable)
        return newmetatable[method_name](t, ...)
      end
      return orig_method(t, ...)
    end
  end
  return metamethod
end

function M.modfilter (filter)
  for tag, fn in pairs(filter) do
    if type(fn) == 'function' then
      filter[tag] = function (elem)
        local t = elem.tag
        if t == tag then
          return fn(elem)
        else
          local customfn = filter[t]
          return customfn and customfn(elem) or elem
        end
      end
    end
  end
  return filter
end

function M.init()
  local BlockMT = debug.getmetatable(pandoc.HorizontalRule())
  local block_walk = BlockMT.methods.walk
  BlockMT.__index = make_new_metamethod(BlockMT, '__index')
  BlockMT.__tostring = make_new_metamethod(BlockMT, '__tostring')
  BlockMT.methods.walk = function (filter, ...)
    return block_walk(M.modfilter(filter), ...)
  end

  local BlocksMT = debug.getmetatable(pandoc.Blocks{})
  local blocks_walk = BlocksMT.walk
  BlocksMT.walk = function (self, filter, ...)
    return blocks_walk(self, M.modfilter(filter), ...)
  end
end

return M

