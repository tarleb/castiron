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
    if debug.getuservalue(t, 1) then
      return orig_method(t, ...)
    else
      local tag = metatable.getters.tag(t)
      -- set caching table, as `t` should now behave like a normal block
      debug.setuservalue(t, {tag = tag}, 1)
      local newtable, newmetatable
      for _, fn in ipairs(custom_from_block[tag]) do
        newtable, newmetatable = fn(t)
        if newtable then
          break
        end
      end
      if newtable then
        debug.setuservalue(t, newtable, 1)
        debug.setmetatable(t, newmetatable)
        return newmetatable[method_name](t, ...)
      end
      return orig_method(t, ...)
    end
  end
  return metamethod
end

function M.init()
  local BlockMT = debug.getmetatable(pandoc.HorizontalRule())
  BlockMT.__index = make_new_metamethod(BlockMT, '__index')
  BlockMT.__tostring = make_new_metamethod(BlockMT, '__tostring')
end

return M

