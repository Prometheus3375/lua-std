function InitPLSL(root_dir)
  -- Prometheus' Lua Standard Library
  PLSL = {}
  PLSL.init = {}

  dofile(root_dir .. '/common.lua')
  PLSL.init.common()

  dofile(root_dir .. '/Class.lua')
  PLSL.init.Class()

  dofile(root_dir .. '/CommonBases.lua')
  PLSL.init.CommonBases()

  dofile(root_dir .. '/CommonEx.lua')
  PLSL.init.ExtendCommonPackage()

  dofile(root_dir .. '/hash.lua')
  PLSL.init.hash()

  PLSL.init = nil
end
