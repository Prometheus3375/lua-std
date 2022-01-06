function InitPLSL(root_dir)
  -- Prometheus' Lua Standard Library
  PLSL = {}

  dofile(root_dir .. '/common.lua')
  dofile(root_dir .. '/Class.lua')
  dofile(root_dir .. '/CommonBases.lua')
  dofile(root_dir .. '/CommonEx.lua')
  dofile(root_dir .. '/hash.lua')
end
