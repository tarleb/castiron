--- castiron – *C*ustom *AST* elements for pandoc Lua
--
-- Copyright: © 2024 Albert Krewinkel <albert+pandoc@tarleb.com>
-- License: MIT

local pandoc = require 'pandoc'
local List   = require 'pandoc.List'
local debug  = require 'debug'

local getuservalue = debug.getuservalue

local M = {}

--- List of functions to convert from pandoc element to custom, indexed by
--- pandoc tag.
local custom_from_block = {}

--- Map from custom elements to the native elements with which they can be
--- marshalled/unmarshalled.
local custom_native_tags = {}

--- Metatable used for the userdata values of custom elements.
-- Delegates most requests to the uservalue.
local custom_block_metatable = {
  __name = 'Block',
  __tostring = function (t)
    return tostring(getuservalue(t, 1))
  end,
  __index = function (t, idx)
    return getuservalue(t, 1)[idx]
  end,
  __newindex = function (t, idx, v)
    getuservalue(t, 1)[idx] = v
  end,
  __toblock = function(t)
    local uv = getuservalue(t, 1)
    local toblock = getmetatable(uv).__toblock
    return toblock
      and toblock(uv)
      or error('custom elements must have a __toblock metamethod')
  end,
}

function M.define_block_element (name, fromblock)
  custom_native_tags[name] = List{}
  for tag, fn in pairs(fromblock) do
    custom_from_block[tag] = custom_from_block[tag] or pandoc.List()
    custom_from_block[tag]:insert(fn)
    custom_native_tags[name]:insert(tag)
  end
end

local function make_new_metamethod (metatable, method_name)
  local orig_method = metatable[method_name]

  local function metamethod (t, ...)
    -- Check if the object already has a caching table
    if getuservalue(t, 1) then
      -- Has a table. Keep as is.
      return orig_method(t, ...)
    else
      -- Doesn't have a caching table yet. Check if it's a
      -- "pandocized" custom element.
      local tag = metatable.getters.tag(t)
      -- set caching table, as `t` should behave like a normal block
      -- in the converter functions.
      debug.setuservalue(t, {tag = tag}, 1)
      local newtable
      for _, fn in ipairs(custom_from_block[tag] or {}) do
        newtable = fn(t)
        if newtable then
          break
        end
      end
      if newtable then
        -- set alternative type
        debug.setuservalue(t, newtable, 1)
        debug.setmetatable(t, custom_block_metatable)
        -- Free the Haskell object associated with this object.
        -- It is no longer needed.
        metatable.__gc(t)
        local newmm = custom_block_metatable[method_name]
        return newmm(t, ...)
      end
      return orig_method(t, ...)
    end
  end
  return metamethod
end

--- Modify the filter so it respects custom elements
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
  -- Make sure that there's a filter for all elements that are used to
  -- encode custom elements. Otherwise the custom elements cannot be
  -- filtered.
  for tag in pairs(custom_from_block) do
    if not filter[tag] then
      filter[tag] = function() end
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

  local InlineMT = debug.getmetatable(pandoc.Space())
  local inline_walk = InlineMT.methods.walk
  InlineMT.methods.walk = function (filter, ...)
    return inline_walk(M.modfilter(filter), ...)
  end

  local BlocksMT = debug.getmetatable(pandoc.Blocks{})
  local blocks_walk = BlocksMT.walk
  BlocksMT.walk = function (self, filter, ...)
    return blocks_walk(self, M.modfilter(filter), ...)
  end

  local InlinesMT = debug.getmetatable(pandoc.Inlines{})
  local inlines_walk = InlinesMT.walk
  InlinesMT.walk = function (self, filter, ...)
    return inlines_walk(self, M.modfilter(filter), ...)
  end

  local PandocMT = debug.getmetatable(pandoc.Pandoc{})
  local pandoc_walk = PandocMT.methods.walk
  PandocMT.walk = function (self, filter, ...)
    return pandoc_walk(self, M.modfilter(filter), ...)
  end
end

return M
