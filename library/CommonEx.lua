function ExtendCommonPackage(common, Class, CB)
  --region Initialization
  common = common or _ENV.common or _ENV.Common
  Class = Class or _ENV.Class
  CB = CB or _ENV.CB or _ENV.CommonBases

  local repr = common.repr
  local type_repr = common.type_repr
  local isclass = common.isclass
  local isinstance = common.isinstance

  local Array = CB.Array
  local Callable = CB.Callable
  local Container = CB.Container
  local Iterable = CB.Iterable
  local Iterator = CB.Iterator
  local Reversible = CB.Reversible

  local function iter(ins, err_level)
    if isinstance(ins, Iterable) then
      return ins:__iter()
    end

    error(repr(ins.__class.__name) .. ' instance is not an iterable', err_level + 1)
  end

  local common_ex = {}
  --endregion

  --region CB extension
  function common_ex.array(ins)
    if isinstance(ins, Array) then
      return ins:__array()
    end

    if isinstance(ins, Iterable) then
      local result = {}
      -- keep it simple, only the first emitted value is added to the result
      for v in ins:__iter() do
        table.insert(result, v)
      end
      return result
    end

    error(repr(ins.__class.__name) .. ' instance cannot be represented as an array', 2)
  end

  function common_ex.contains(ins, value)
    if isinstance(ins, Container) then
      return ins:__contains(value)
    end

    error(repr(ins.__class.__name) .. ' instance is not a container', 2)
  end

  function common_ex.inext(ins)
    if isinstance(ins, Iterator) then
      return ins:__inext()
    end

    error(repr(ins.__class.__name) .. ' instance is not an iterator', 2)
  end

  function common_ex.iter(ins)
    if isinstance(ins, Iterable) then
      return ins:__iter()
    end

    error(repr(ins.__class.__name) .. ' instance is not an iterable', 2)
  end

  function common_ex.reverse(ins)
    if isinstance(ins, Reversible) then
      return ins:__reverse()
    end

    error(repr(ins.__class.__name) .. ' instance is not reversible', 2)
  end
  --endregion

  function common_ex.all(iterable)
    for v in iter(iterable, 2) do
      if not v then return false end
    end
    return true
  end

  function common_ex.any(iterable)
    for v in iter(iterable, 2) do
      if v then return true end
    end
    return false
  end

  function common_ex.sum(iterable)
    local sum = 0
    for v in iter(iterable, 2) do
      sum = sum + v
    end
    return sum
  end

  function common_ex.callable(v)
    return type(v) == 'function' or isclass(v) or isinstance(v, Callable)
  end

  --region enumerate
  local enumerate = {}
  function enumerate:__init(iterable, start)
    if start ~= nil and type(start) ~= 'number' then
      error('start must be a number or nil, got ' .. type_repr(start), 3)
    end
    local iterator, state, init_value = iter(iterable, 3)

    local values = self.__values
    values.index = (start or 1) - 1
    values.iterator = iterator
    values.state = state
    values.v = init_value
  end

  function enumerate:__inext()
    local values = self.__values
    local result = table.pack(values.iterator(values.state, values.v))
    local var = result[1]
    if var ~= nil then
      local index = values.index + 1
      values.index = index
      values.v = var
      return index, table.unpack(result, 1, result.n)
    end

    return nil
  end

  common_ex.enumerate = Class('enumerate', enumerate, Iterator)
  --endregion

  --region filter
  local filter = {}
  local function default_filter(v) return v end

  function filter:__init(iterable, filter_func)
    if filter_func ~= nil and type(filter_func) ~= 'function' then
      error('filter_func must be a function or nil, got ' .. type_repr(filter_func), 3)
    end
    local iterator, state, init_value = iter(iterable, 3)

    local values = self.__values
    values.filter = filter_func or default_filter
    values.iterator = iterator
    values.state = state
    values.v = init_value
  end

  function filter:__inext()
    local values = self.__values
    local iterator = values.iterator
    local state = values.state
    local var = values.v
    local f = values.filter
    repeat
      var = iterator(state, var)
      if var == nil then return nil end
    until f(var)

    values.v = var
    return var
  end

  common_ex.filter = Class('filter', filter, Iterator)
  --endregion

  --region map
  local map = {}
  function map:__init(map_func, ...)
    if type(map_func) ~= 'function' then
      error('map_func must be a function, got ' .. type_repr(map_func), 3)
    end
    local iterables = table.pack(...)
    if iterables.n == 0 then
      error('no iterable is passed', 3)
    end

    local iterators = {}
    for i = 1, iterables.n do
      local it, s, v = iter(iterables[i], 3)
      table.insert(iterators, {iterator = it, state = s, v = v})
    end

    self.__values.map = map_func
    self.__values.iterators = iterators
  end

  function map:__inext()
    local args = {}
    for _, t in ipairs(self.__values.iterators) do
      local var = t.iterator(t.state, t.v)
      if var == nil then return nil end
      t.v = var
      table.insert(args, var)
    end

    return self.__values.map(table.unpack(args))
  end

  common_ex.map = Class('map', map, Iterator)
  --endregion

  --region zip
  local zip = {}
  function zip:__init(...)
    local args = table.pack(...)
    if args.n == 0 then
      error('no iterable is passed', 3)
    end

    local iterables = {}
    for i = 1, args.n do
      local it, s, v = iter(args[i], 3)
      table.insert(iterables, {iterator = it, state = s, v = v})
    end

    self.__values.iterables = iterables
  end

  function zip:__inext()
    local result = {}
    for _, t in ipairs(self.__values.iterables) do
      local var = t.iterator(t.state, t.v)
      if var == nil then return nil end
      t.v = var
      table.insert(result, var)
    end

    return result
  end

  common_ex.zip = Class('zip', zip, Iterator)
  --endregion

  --region zip_strict
  local zip_strict = {__init = zip.__init}

  function zip_strict:__inext()
    local result = {}
    local nil_count = 0
    local nils = {}
    for i, t in ipairs(self.__values.iterables) do
      local var = t.iterator(t.state, t.v)
      if var == nil then
        nil_count = nil_count + 1
        nils[i] = true
      else
        nils[i] = false
        t.v = var
        table.insert(result, var)
      end
    end

    if nil_count == #nils then
      return nil
    elseif nil_count == 0 then
      return result
    end

    local nil_var = {}
    local has_var = {}
    for i, b in ipairs(nils) do
      table.insert(b and nil_var or has_var, i)
    end

    error(
      string.format(
        '%s() argument%s %s %s longer than argument%s %s',
        self.__class.__name,
        #has_var == 1 and '' or 's',
        table.concat(has_var, ', '),
        #has_var == 1 and 'is' or 'are',
        #nil_var == 1 and '' or 's',
        table.concat(nil_var, ', ')
      ),
      2
    )
  end

  common_ex.zip_strict = Class.zip_strict('zip_strict', zip_strict, Iterator)
  --endregion

  -- todo max, min, sorted, range
  -- https://docs.python.org/3/library/functions.html

  for name, value in pairs(common_ex) do
    rawset(common, name, value)
  end
end
