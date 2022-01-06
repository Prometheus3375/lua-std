function PLSL.init.CommonBases()
  --region Initialization
  local common = PLSL.common
  local Class = PLSL.Class
  local Interface = PLSL.Interface

  local Method = Interface.Method

  local CB = {}
  --endregion

  CB.Callable = Interface('Callable', true, {__call = Method('self, ...', true)})
  CB.SupportsLessThan = Interface('SupportsLessThan', true, {__lt = Method('self, other', true)})

  CB.Container = Interface('Container', true, {__contains = Method('self, value', false)})
  CB.Iterable = Interface('Iterable', true, {__iter = Method('self', false)})
  CB.Reversible = Interface('Reversible', true, {__reverse = Method('self', false)})

  CB.SupportsGetNumericKey = Interface(
    'SupportsGetNumericKey',
    true,
    {__get_numeric_key = Method('self, key', false)}
  )

  CB.SupportsSetNumericKey = Interface(
    'SupportsSetNumericKey',
    true,
    {__set_numeric_key = Method('self, key, value', false)}
  )

  local default_len = Class('temp1', {}).__meta.__len

  local function sized_check_imp_absence(func)
    return func == default_len or (func ~= nil and type(func) ~= 'function')
  end

  CB.Sized = Interface('Sized', true, {__len = Method('self', true, nil, sized_check_imp_absence)})

  local function iterator_iter(self) return self end
  local function iterator_call(self)
    -- rewrite __call in meta so that next call will use __inext directly
    local inext = self.__class.__inext
    self.__class.__meta.__call = inext
    return inext(self)
  end

  CB.Iterator = Interface(
    'Iterator',
    true, {
      __iter = Method('self', false, iterator_iter),
      __call = Method('self', true, iterator_call),
      __inext = Method('self', false),
    },
    CB.Iterable,
    CB.Callable
  )

  CB.Collection = Interface('Collection', true, {}, CB.Container, CB.Iterable, CB.Sized)
  CB.OrderedCollection = Interface('OrderedCollection', true, {}, CB.Collection, CB.Reversible)

  PLSL.CommonBases = setmetatable(CB, common.generate_package_metatable('PLSL.CommonBases'))
end
