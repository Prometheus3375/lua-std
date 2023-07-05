function InitCommonPackage()
  local common = {}

  function common.repr(v)
    if type(v) == 'string' then
      v = string.format('%q', v)
      if string.find(v, '\'', 1, true) then
        return v
      end
      return "'" .. string.sub(v, 2, -2) .. "'"
    end

    return tostring(v)
  end

  local repr = common.repr

  function common.type_repr(v)
    local t = type(v)
    v = repr(v)

    if string.match(v, '^' .. t) then
      return v
    end
    return t .. ' ' .. v
  end

  function common.rawlen(t)
    local index = 1
    while rawget(t, index) ~= nil do
      index = index + 1
    end
    return index - 1
  end

  function common.rawpairs(t)
    return next, t, nil
  end

  local function rawipairs_next(t, index)
    index = index + 1
    local value = rawget(t, index)
    if value ~= nil then
      return index, value
    end

    return nil
  end

  function common.rawipairs(t)
    return rawipairs_next, t, 0
  end

  function common.number2index(num)
    local rem = num % 100
    if rem == 11 or rem == 12 or rem == 13 then
      return num .. 'th'
    end

    rem = num % 10
    if rem == 1 then
      return num .. 'st'
    end
    if rem == 2 then
      return num .. 'nd'
    end
    if rem == 3 then
      return num .. 'rd'
    end

    return num .. 'th'
  end

  function common.table_length(t)
    local n = 0
    for _, _ in pairs(t) do
      n = n + 1
    end
    return n
  end

  -- todo: create package primitive set for all set operations?
  function common.array2set(a)
    local s = {}
    for _, v in ipairs(a) do
      s[v] = true
    end
    return s
  end

  function common.set2array(s)
    local a = {}
    for v, _ in pairs(s) do
      table.insert(a, v)
    end
    return a
  end

  function common.set_union(result, ...)
    result = result or {}
    for _, s in ipairs({result, ...}) do
      for v, _ in pairs(s) do
        result[v] = true
      end
    end
    return result
  end

  local function enum_next(state, index)
    -- 1 - iterator function
    -- 2 - state of the iterator
    -- 3 - last value generated by the iterator
    local result = table.pack(state[1](state[2], state[3]))
    local value = result[1]
    if value ~= nil then
      state[3] = value
      return index + 1, table.unpack(result, 1, result.n)
    end

    return nil
  end

  function common.enum(start, iterator, state, init_value)
    return enum_next, {iterator, state, init_value}, (start or 1) - 1
  end

  function common.enum_pairs(t, start, raw)
    return enum_next, raw and {next, t, nil} or {pairs(t)}, (start or 1) - 1
  end

  function common.generate_protected_metatable(name, plural)
    local name_do = name .. (plural and ' do not ' or ' does not ')
    return {
      __len = function() error(name_do .. 'support length operator', 2) end,
      __index = function(_, key) error(name_do .. 'have key ' .. repr(key), 2) end,
      __newindex = function(_, key, _) error(name_do .. 'have key ' .. repr(key) .. ' to set', 2) end,
      __ipairs = function() error(name_do .. 'support ipairs()', 2) end,
      __pairs = function() error(name_do .. 'support pairs()', 2) end,
      __metatable = true,
    }
  end

  local generate_protected_metatable = common.generate_protected_metatable

  function common.generate_package_metatable(name)
    name = 'package ' .. repr(name)
    local meta = generate_protected_metatable(name, false)
    meta.__pairs = nil
    function meta.__tostring() return '<' .. name .. '>' end
    return meta
  end

  function common.expose_package(package, global, renames, exclude)
    global = global or _ENV
    renames = renames or {}
    exclude = exclude or {}
    for name, field in pairs(package) do
      if renames[name] then
        global[renames[name]] = field
      elseif not exclude[name] then
        global[name] = field
      end
    end
  end

  --region None
  local none_metatable = generate_protected_metatable('None', false)
  function none_metatable.__tostring() return 'None' end
  local None = setmetatable({}, none_metatable)

  common.None = None

  function common.isNone(ins)
    return rawequal(ins, None)
  end

  function common.isNoneOrNil(ins)
    return rawequal(ins, None) or ins == nil
  end

  function common.toNil(ins)
    if rawequal(ins, None) then
      return nil
    end
    return ins
  end

  function common.toNone(ins)
    if ins == nil then
      return None
    end
    return ins
  end
  --endregion

  return setmetatable(common, common.generate_package_metatable('Common'))
end
