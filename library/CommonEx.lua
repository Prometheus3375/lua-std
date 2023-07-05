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
  local SupportsGetNumericKey = CB.SupportsGetNumericKey

  local common_ex = {}
  --endregion

  --region Local functions and objects
  local iterator_wrapper = {}

  function iterator_wrapper:__init(func, state, init_value)
    local values = self.__values
    values.func = func
    values.state = state
    values.v = init_value
  end

  function iterator_wrapper:__inext()
    local values = self.__values
    local result = table.pack(values.func(values.state, values.v))
    local var = result[1]
    if var ~= nil then
      values.v = var
      return table.unpack(result, 1, result.n)
    end

    return nil
  end

  iterator_wrapper = Class('IteratorWrapper', iterator_wrapper, Iterator)

  local function is_sequence(v)
    if type(v) ~= 'table' then return false end
    local k = next(v)
    return k == nil or type(k) == 'number' or isinstance(v, SupportsGetNumericKey)
  end

  local sequence_iterator = {}

  function sequence_iterator:__init(sequence)
    self.__values.seq = sequence
    self.__values.index = 0
  end

  function sequence_iterator:__inext()
    local values = self.__values
    local index = values.index + 1
    local var = values.seq[index]
    if var ~= nil then
      values.index = index
      return var
    end

    return nil
  end

  sequence_iterator = Class('SequenceIterator', sequence_iterator, Iterator)

  local function type_error(ins, err, level)
    level = (level or 1) + 1
    if isinstance(ins) then
      error(repr(ins.__class.__name) .. ' instance ' .. err, level)
    end
    error(type_repr(ins) .. err, level)
  end

  local function iter(ins, err_level)
    if isinstance(ins, Iterable) then
      local f, s, v = ins:__iter()

      if isinstance(f, Iterator) then
        return f
      end

      if type(f) == 'function' then
        return iterator_wrapper(f, s, v)
      else
        error('first return value of __iter method must be an iterator instance or function, '
          .. ins.__class.__name .. '.__iter() returned ' .. type_repr(f), (err_level or 1) + 1)
      end
    end

    if is_sequence(ins) then
      return sequence_iterator(ins)
    end

    type_error(ins, 'is not an iterable', (err_level or 1) + 1)
  end
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

    if is_sequence(ins) then
      return ins
    end

    type_error(ins, 'cannot be represented as an array', 2)
  end

  function common_ex.contains(ins, value)
    if isinstance(ins, Container) then
      return ins:__contains(value)
    end

    type_error(ins, 'is not a container', 2)
  end

  function common_ex.inext(ins)
    if isinstance(ins, Iterator) then
      return ins:__inext()
    end

    type_error(ins, 'is not an iterator', 2)
  end

  common_ex.iter = iter

  function common_ex.reverse(ins)
    if isinstance(ins, Reversible) then
      return ins:__reverse()
    end

    type_error(ins, 'is not reversible', 2)
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

  function common_ex.sum(iterable, start)
    local sum = start or 0
    for v in iter(iterable, 2) do
      sum = sum + v
    end
    return sum
  end

  function common_ex.is_callable(v)
    return type(v) == 'function' or isclass(v) or isinstance(v, Callable)
  end

  common_ex.is_sequence = is_sequence

  --region enumerate
  local enumerate = {}
  function enumerate:__init(iterable, start)
    if start ~= nil and type(start) ~= 'number' then
      error('start must be a number or nil, got ' .. type_repr(start), 3)
    end
    local iterator = iter(iterable, 3)

    local values = self.__values
    values.index = (start or 1) - 1
    values.iterator = iterator
  end

  function enumerate:__inext()
    local values = self.__values
    local result = table.pack(values.iterator())
    local var = result[1]
    if var ~= nil then
      local index = values.index + 1
      values.index = index
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
    local iterator = iter(iterable, 3)

    local values = self.__values
    values.filter = filter_func or default_filter
    values.iterator = iterator
  end

  function filter:__inext()
    local values = self.__values
    local iterator = values.iterator
    local f = values.filter
    local var
    repeat
      var = iterator()
      if var == nil then return nil end
    until f(var)

    return var
  end

  common_ex.filter = Class('filter', filter, Iterator)
  --endregion

  common_ex.IteratorWrapper = iterator_wrapper

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
      table.insert(iterators, iter(iterables[i], 3))
    end

    self.__values.map = map_func
    self.__values.iterators = iterators
  end

  function map:__inext()
    local args = {}
    for i, iterator in ipairs(self.__values.iterators) do
      local var = iterator()
      if var == nil then return nil end
      args[i] = var
    end

    return self.__values.map(table.unpack(args))
  end

  common_ex.map = Class('map', map, Iterator)
  --endregion

  common_ex.SequenceIterator = sequence_iterator

  --region zip
  local zip = {}
  function zip:__init(...)
    local args = table.pack(...)
    if args.n == 0 then
      error('no iterable is passed', 3)
    end

    local iterators = {}
    for i = 1, args.n do
      table.insert(iterators, iter(args[i], 3))
    end

    self.__values.iterators = iterators
  end

  function zip:__inext()
    local result = {}
    for i, iterator in ipairs(self.__values.iterators) do
      local var = iterator()
      if var == nil then return nil end
      result[i] = var
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
    for i, iterator in ipairs(self.__values.iterators) do
      local var = iterator()
      if var == nil then
        nil_count = nil_count + 1
        nils[i] = true
      else
        nils[i] = false
        result[i] = var
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

  common_ex.zip_strict = Class('zip_strict', zip_strict, Iterator)
  --endregion

  -- todo max, min, sorted, range
  -- https://docs.python.org/3/library/functions.html

  for name, value in pairs(common_ex) do
    rawset(common, name, value)
  end
end
