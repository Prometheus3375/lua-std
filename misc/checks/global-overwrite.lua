PLSL = 'My PLSL'
print(PLSL)  -- 1
local plsl = require('library')
print(PLSL)  -- 2
print(plsl)  -- 3

-- 1 prints 'My PLSL'
-- If init.lua sets back old values of PLSL var, 2 prints 'My PLSL'
-- Otherwise, 2 prints the same strings as 3 does
