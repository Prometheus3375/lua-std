do
  local added = {}
  added[_G] = true

  local function repr(v)
    if type(v) == 'string' then
      v = string.format('%q', v)
      v = string.gsub(v, '\n', 'n')
      if string.find(v, '\'', 1, true) then
        return v
      end
      return "'" .. string.sub(v, 2, -2) .. "'"
    end

    return tostring(v)
  end

  local function recursive_iteration(t, name, level)
    level = level or 0
    local key_array = {}
    local indent = string.rep(' ', level)

    for k, _ in pairs(t) do
      table.insert(key_array, k)
    end
    table.sort(key_array)

    for _, k in ipairs(key_array) do
      local v = t[k]
      local is_added = added[v]
      if is_added then
        if type(is_added) == 'string' then
          print(indent .. k .. ' -- ' .. repr(v) .. ' (mentioned in ' .. is_added .. ')')
        end
      else
        added[v] = name
        print(indent .. k .. ' -- ' .. repr(v))
        if type(v) == 'table' then
          recursive_iteration(v, name .. '.' .. k, level + 2)
        end
      end
    end
  end

  recursive_iteration(_G, '_G')
end
