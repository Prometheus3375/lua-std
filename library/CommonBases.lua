function InitCommonBases(common, Interface)
  --region Initialization
  common = common or _ENV.common or _ENV.Common
  Interface = Interface or _ENV.Interface

  local def_method = Interface.DefineMethod

  local CB = {}
  --endregion

  local method = {
    contains = def_method('__contains', '(self, value)'),
    iter = def_method('__iter', '(self)'),
    inext = def_method('__inext', '(self)'),
    reverse = def_method('__reverse', '(self)'),
    len = def_method('__len', '(self)', true),
    call = def_method('__call', '(self, ...)', true),
    array = def_method('__array', '(self)'),
  }

  CB.Array = Interface('Array', true, {method.array})
  CB.Callable = Interface('Callable', true, {method.call})
  CB.Container = Interface('Container', true, {method.contains})
  CB.Iterable = Interface('Iterable', true, {method.iter})
  CB.Reversible = Interface('Reversible', true, {method.reverse})
  CB.Sized = Interface('Sized', true, {method.len})
  CB.Collection = Interface('Collection', true, {}, CB.Container, CB.Iterable, CB.Sized)
  CB.OrderedCollection = Interface('OrderedCollection', true, {}, CB.Collection, CB.Reversible)

  local function iterator_iter(self) return self end
  local function iterator_call(self)
    -- rewrite __call in meta so that next call will use __inext directly
    local inext = self.__class.__inext
    self.__class.__meta.__call = inext
    return inext(self)
  end

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

  return setmetatable(CB, common.generate_package_metatable('Common Bases'))
end
