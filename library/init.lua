--[[

      Prometheus' Lua Standard Library

--]]

local _, path = ...
local root = string.sub(path, 1, -9)  -- length of the string 'init.lua'

local old = PLSL
local library = {}
PLSL = library

dofile(root .. 'common.lua')
dofile(root .. 'Class.lua')
dofile(root .. 'CommonBases.lua')
dofile(root .. 'CommonEx.lua')

-- todo protect PLSL

PLSL = old

return library


-- todo do not use upvalues, use lib functions instead?
-- todo add format argument to str and __str
-- todo in all files return values, do not assign them to PLSL
--   this is necessary for correct linking to docs later
-- todo remove useless do end
