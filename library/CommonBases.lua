function InitCommonBases(common, Interface)
  --region Initialization
  common = common or _ENV.common or _ENV.Common
  Interface = Interface or _ENV.Interface

  local CB = {}

  local repr = common.repr
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
    array = def_method('__array', '(self)'),
  }

  CB.Container = Interface('Container', true, {method.contains})
  CB.Iterable = Interface('Iterable', true, {method.iter})
  CB.Reversible = Interface('Reversible', true, {method.reverse})
  CB.Sized = Interface('Sized', true, {method.len})
  CB.Callable = Interface('Callable', true, {method.call})
  CB.Collection = Interface('Collection', true, {}, CB.Container, CB.Iterable, CB.Sized)
  CB.OrderedCollection = Interface('OrderedCollection', true, {}, CB.Collection, CB.Reversible)
  CB.Array = Interface('Array', true, {method.array})

  local function iterator_iter(self) return self end
  local function iterator_call(self) return self:__inext() end

  CB.Iterator = Interface(
    'Iterator',
    {
      method.iter:WithDefault(iterator_iter),
      method.call:WithDefault(iterator_call),
      method.inext,
    },
    CB.Iterable,
    CB.Callable
  )
  --endregion

  --region Common
  -- todo move to CommonEx.lua
  -- todo remove err_level from all functions
  -- todo inline not_of_type
  local function not_of_type(ins, typ, level)
    error(repr(ins.__class.__name) .. ' instance is not ' .. typ, level + 1)
  end

  local common_ex = {}
  local Container = CB.Container
  local Iterable = CB.Iterable
  local Iterator = CB.Iterator
  local Reversible = CB.Reversible
  local Array = CB.Array

  function common_ex.contains(container, value, err_level)
    if isinstance(container, Container) then
      return container:__contains(value)
    end

    not_of_type(container, 'a container', (err_level or 1) + 1)
  end

  function common_ex.iter(iterable, err_level)
    if isinstance(iterable, Iterable) then
      return iterable:__iter()
    end

    not_of_type(iterable, 'an iterable', (err_level or 1) + 1)
  end

  function common_ex.inext(iterator, err_level)
    if isinstance(iterator, Iterator) then
      return iterator:__inext()
    end

    not_of_type(iterator, 'an iterator', (err_level or 1) + 1)
  end

  function common_ex.reverse(reversible, err_level)
    if isinstance(reversible, Reversible) then
      return reversible:__reverse()
    end

    not_of_type(reversible, 'reversible', (err_level or 1) + 1)
  end

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

    error(repr(ins.__class.__name) .. ' instance cannot be represented as array', 2)
  end

  for name, value in pairs(common_ex) do
    rawset(common, name, value)
  end
  --endregion

  return setmetatable(CB, common.generate_package_metatable('Common Bases'))
end
