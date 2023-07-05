do
  --region Initialization
  local common = PLSL.common

  local repr = common.repr
  local isNone = common.isNone
  local isclass = common.isclass
  local isinterface = common.isinterface
  local isinstance = common.isinstance
  local iter = common.iter

  local Hashable = PLSL.CommonBases.Hashable

  local hash = {}
  --endregion

  -- todo hash
  -- number hash: https://docs.python.org/3/library/stdtypes.html#typesnumeric
  -- detect if number is int: https://stackoverflow.com/questions/36063303/lua-5-3-integers-type-lua-type/36063799
  -- tuple hash: https://stackoverflow.com/questions/49722196/how-does-python-compute-the-hash-of-a-tuple
  -- set hash in collections abc
  -- string hash: ???

  hash.None = 0  -- todo maybe not zero?

  function hash.boolean(b)
    return b and 1 or 0
  end

  function hash.rational(n, m)

  end

  function hash.number(num)

  end

  function hash.string(s)

  end

  hash.table = common.get_address
  hash.function_ = common.get_address
  hash['function'] = hash.function_
  hash.thread = common.get_address
  hash.userdata = common.get_address

  function hash.instance(ins)
    if isinstance(ins, Hashable) then
      return ins:__hash()
    end
  end

  function hash.class(cls)
    return cls.__id
  end

  function hash.interface(itf)
    return itf.__id
  end

  local function calculate(v)
    if v == nil then
      return nil
    elseif isNone(v) then
      return hash.None
    elseif isclass(v) then
      return hash.class(v)
    elseif isinterface(v) then
      return hash.interface(v)
    elseif isinstance(v) then
      return hash.instance(v)
    else
      return hash[type(v)]
    end
  end

  hash.calculate = calculate

  local function strict_calculate(v)
    local result = calculate(v)

    if math.type(result) ~= 'integer' then
      error(repr(v) .. ' is not hashable', 2)
    end

    return result
  end

  rawset(common, 'hash', strict_calculate)

  function hash:sequence()

  end

  function hash:set()

  end

  -- accepts an iterable of key-value pairs
  function hash:mapping()
    return hash.set(self)
  end

  PLSL.hash = setmetatable(hash, common.generate_module_metatable('PLSL.hash'))
end
