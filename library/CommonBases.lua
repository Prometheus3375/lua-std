function InitCommonBases(common, Interface)
  --region Initialization
  common = common or _ENV.common or _ENV.Common
  Interface = Interface or _ENV.Interface

  local CB = {}

  local isinstance = common.isinstance
  local def_method = Interface.DefineMethod
  --endregion

  --region Bases
  local method = {
    contains = def_method('__contains', '(self, value)'),
    iter = def_method('__iter', '(self)'),
    inext = def_method('__inext', '(self)'),
    reverse = def_method('__reverse', '(self)'),
    len = def_method('__len', '(self)', true),
    call = def_method('__call', '(self, ...)', true),
  }

  CB.Container = Interface('Container', {method.contains})
  CB.Iterable = Interface('Iterable', {method.iter})
  CB.Reversible = Interface('Reversible', {method.reverse})
  CB.Sized = Interface('Sized', {method.len})
  CB.Callable = Interface('Callable', {method.call})
  CB.Collection = Interface('Collection', {}, CB.Container, CB.Iterable, CB.Sized)
  CB.OrderedCollection = Interface('OrderedCollection', {}, CB.Collection, CB.Reversible)

  local function iterator_iter(self) return self end

  CB.Iterator = Interface(
    'Iterator',
    {
      method.iter:WithDefault(iterator_iter),
      method.inext,
    },
    CB.Iterable
  )

  local function is_registered_or_check_methods(self, cls)
    if self.__registered[cls] then
      return 2
    end

    for _, m_table in ipairs(self.__methods) do
      local m = m_table.is_metamethod and cls.__meta[m_table.name] or cls[m_table.name]
      if type(m) ~= 'function' then
        return 0
      end
    end

    return 1
  end

  local function is_registered_or_check_methods_and_register(self, cls)
    local registered = is_registered_or_check_methods(self, cls)
    if registered == 2 then
      return true
    end

    -- check methods of ancestors
    for _, p in ipairs(self.__all_supers_array) do
      registered = is_registered_or_check_methods(p, cls)
      if registered == 0 then
        return false
      end
    end

    -- Why not register for each parent in the loop above?
    -- Because some interfaces have parent with no methods (OrderedCollection and Collection).
    -- For them the result will be 1, but the result for their parent can be 0.
    -- Thus, register for self and parents only when all parents are checked.
    self:Register(cls)

    return true
  end

  for _, base in pairs(CB) do
    rawset(base, 'IsRegistered', is_registered_or_check_methods_and_register)
  end
  --endregion

  --region Common
  local function not_of_type(ins, typ, level)
    error('instance of type ' .. ins.__class.__name .. ' is not ' .. typ, level)
  end

  local common_ex = {}
  local Container = CB.Container
  local Iterable = CB.Iterable
  local Iterator = CB.Iterator
  local Reversible = CB.Reversible

  function common_ex.contains(container, value)
    if isinstance(container, Container) then
      return container:__contains(value)
    end

    not_of_type(container, 'a container', 3)
  end

  function common_ex.iter(iterable)
    if isinstance(iterable, Iterable) then
      return iterable:__iter()
    end

    not_of_type(iterable, 'an iterable', 3)
  end

  function common_ex.inext(iterator)
    if isinstance(iterator, Iterator) then
      return iterator:__inext()
    end

    not_of_type(iterator, 'an iterator', 3)
  end

  function common_ex.reverse(reversible)
    if isinstance(reversible, Reversible) then
      return reversible:__reverse()
    end

    not_of_type(reversible, 'a reversible', 3)
  end

  for name, value in pairs(common_ex) do
    rawset(common, name, value)
  end
  --endregion

  return setmetatable(CB, common.generate_package_metatable('CommonBases'))
end
