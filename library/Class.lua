function InitClassPackage(common)
  --region Initialization
  common = common or _ENV.common or _ENV.Common

  local repr = common.repr
  local type_repr = common.type_repr
  local number2index = common.number2index
  local string_split = common.string_split
  local set2array = common.set2array
  local set_union = common.set_union
  local isNone = common.isNone
  local gen_meta = common.generate_protected_metatable
  local gen_pack_meta = common.generate_package_metatable

  local __meta_weak_keys = {__mode = 'k'}
  local __meta_weak_values = {__mode = 'v'}

  local Class = {}
  local Interface = {}

  local known_classes = setmetatable({}, __meta_weak_keys)
  local known_interfaces = setmetatable({}, __meta_weak_keys)

  local function isclass(cls) return known_classes[cls] or false end
  local function isinterface(itf) return known_interfaces[itf] or false end

  local class_names = setmetatable({}, __meta_weak_values)
  local interface_names = setmetatable({}, __meta_weak_values)

  local function get_names(t, as_set)
    if as_set then
      return set_union({}, t)
    end

    local result = set2array(t)
    table.sort(result)
    return result
  end

  function Class.GetByName(name) return class_names[name] end
  function Class.GetNames(as_set) return get_names(class_names, as_set) end
  function Interface.GetByName(name) return interface_names[name] end
  function Interface.GetNames(as_set) return get_names(interface_names, as_set) end
  --endregion

  --region Class variables
  local known_indexers = setmetatable({}, __meta_weak_keys)
  local function is_indexer(v) return known_indexers[v] or false end

  function Class.field(public)
    local result = {type = 'field', public = public and true or false}
    known_indexers[result] = true
    return result
  end

  function Class.property(getter, setter)
    if getter == nil and setter == nil then
      error('property must have either a getter or a setter or both', 2)
    elseif getter ~= nil and type(getter) ~= 'function' then
      error('property getter must be a function, got ' .. repr(getter), 2)
    elseif setter ~= nil and type(setter) ~= 'function' then
      error('property setter must be a function, got ' .. repr(setter), 2)
    end
    local result = {type = 'property', getter = getter, setter = setter}
    known_indexers[result] = true
    return result
  end

  function Class.meta(value)
    if value == nil then
      error('meta must have a value', 2)
    end
    local result = {type = 'meta', value = value}
    known_indexers[result] = true
    return result
  end

  local class_key_initializers = {
    field = function(cls, key, description)
      if description.public then
        cls.__public[key] = true
      else
        cls.__readonly[key] = true
      end
    end,

    property = function(cls, key, description)
      cls.__properties[key] = {
        getter = description.getter,
        setter = description.setter,
      }
    end,

    meta = function(cls, key, description)
      cls.__meta[key] = description.value
    end,
  }

  local function index(self, cls, key)
    -- process numeric keys
    if type(key) == 'number' then
      if cls.__get_numeric_key then
        return cls.__get_numeric_key(self, key)
      else
        error(repr(cls.__name) .. ' instance cannot get numeric keys', 3)
      end
    end
    -- fallback for nil public fields and super object
    if cls.__public[key] then
      return rawget(self, key)
    end
    -- readonly fields
    if cls.__readonly[key] then
      return self.__values[key]
    end
    -- getters
    local value = cls.__properties[key]
    if value then
      return value.getter(self)
    end
    -- class fields and methods
    value = cls[key]
    if value ~= nil then
      return value
    end
    error(repr(cls.__name) .. ' instance does not have gettable key ' .. repr(key), 3)
  end

  local function newindex(self, cls, key, value)
    -- process numeric keys
    if type(key) == 'number' then
      if cls.__set_numeric_key then
        cls.__set_numeric_key(self, key, value)
        return
      else
        error(repr(cls.__name) .. ' instance cannot set numeric keys', 3)
      end
    end
    -- fallback for nil public fields and super object
    if cls.__public[key] then
      rawset(self, key, value)
      return
    end
    -- setters
    local prop = cls.__properties[key]
    if prop then
      prop.setter(self, value)
      return
    end

    error(repr(cls.__name) .. ' instance does not have settable key ' .. repr(key), 3)
  end

  local function class_len() error('classes do not support length operator', 2) end
  local function class_pairs() error('classes do not support pairs()', 2) end

  local function class_newindex(self, key, _)
    error('class ' .. repr(self.name) .. ' does not have key ' .. repr(key) .. ' to set', 2)
  end

  local function class_tostring(cls)
    return '<class ' .. repr(cls.__name) .. '>'
  end

  local function class_new_instance(cls, ...)
    local self = {
      __class = cls,
      __values = {},
    }
    setmetatable(self, cls.__meta)
    cls.__init(self, ...)
    return self
  end

  local function instance_len(self)
    error(repr(self.__class.__name) .. ' instance does not support length operator', 2)
  end

  local function instance_newindex(self, key, value)
    newindex(self, self.__class, key, value)
  end

  local function instance_index(self, key)
    return index(self, self.__class, key)
  end

  local function instance_pairs(self)
    error(repr(self.__class.__name) .. ' instance does not support pairs()', 2)
  end

  function Class.tostring(ins)
    local meta = ins.__class.__meta
    local str = rawget(meta, '__tostring')
    if str then
      meta.__tostring = nil
      local result = tostring(ins)
      meta.__tostring = str
      return result
    end

    return tostring(ins)
  end

  local instance_raw_tostring = Class.tostring

  function Class.addressof(ins)
    return string.sub(instance_raw_tostring(ins), string.len(ins.__class.__meta.__name) + 3)
  end

  local super_meta = {__metatable = true}

  -- If superclass does not have __len, but the class of instance has,
  -- then the error states that class of instance does not have __len.
  -- Thus, checks are added to __len and __pairs to emit correct errors.
  function super_meta:__len()
    local len = self.__class.__meta.__len
    if len == instance_len then
      error(repr(self.__class.__name) .. ' instance does not support length operator', 2)
    end

    -- fallback if superclass does not have __len, but own class has
    if len == nil then
      local meta = self.__ins.__class.__meta
      if meta then
        len = meta.__len
        local result = #self.__ins
        meta.__len = len
        return result
      end
      return #self.__ins
    end

    return len(self.__ins)
  end

  function super_meta:__index(key)
    return index(self.__ins, self.__class, key)
  end

  function super_meta:__newindex(key, value)
    newindex(self.__ins, self.__class, key, value)
  end

  function super_meta:__pairs()
    local pairs = self.__class.__meta.__pairs
    if pairs == instance_pairs then
      error(repr(self.__class.__name) .. ' instance does not support pairs()', 2)
    end

    -- fallback if superclass does not have __len, but own class has
    if pairs == nil then
      return next, self.__ins, nil
    end

    return pairs(self.__ins)
  end

  -- super object must have a string representation for debugging
  -- Thus, it is not possible to use superclass' __tostring
  function super_meta:__tostring()
    return '<super: ' .. tostring(self.__class) .. ', <' .. self.__ins.__class.__meta.__name .. '>>'
  end

  local function super_get_parent(cls, parent)
    if isclass(parent) then
      if not cls.__superclasses[parent] then
        error('class ' .. repr(cls.__name) .. ' does not have superclass ' .. repr(parent.__name), 3)
      end
    elseif parent == nil then
      parent = cls.__superclass
      if parent == nil then
        error('class ' .. repr(cls.__name) .. ' does not have a superclass', 3)
      end
    else
      error('the second argument must be either a class or nil, got ' .. repr(parent), 3)
    end

    return parent
  end

  function Class.super(ins, parent)
    parent = super_get_parent(ins.__class, parent)
    return setmetatable({__ins = ins, __class = parent}, super_meta)
  end

  local addressof = Class.addressof

  function Class.super_tostring(ins, parent)
    parent = super_get_parent(ins.__class, parent)
    local meta = parent.__meta
    local str = meta.__tostring
    if str then return str(ins) end

    return meta.__name .. ': ' .. addressof(ins)
  end

  local class_indexers = {
    '__public',
    '__readonly',
    '__properties',
  }

  local prohibited_keys = common.array2set({
    -- instance keys
    '__class',
    '__values',
    -- class keys
    '__name',
    '__public',
    '__readonly',
    '__properties',
    '__superclass',
    '__superclasses',
    '__interfaces',
    '__subclasses',
    '__sub_metas',
    '__meta',
    -- meta keys for instances
    '__newindex',
    '__index',
    -- super keys
    '__ins',
    '__class',
  })

  local special_keys = {
    __init = 'function',
    __get_numeric_key = 'function',
    __set_numeric_key = 'function',
  }

  local function empty_function() end
  local interface_prepare_class_deftable

  local function create_class(name, deftable, ...)
    --region Check arguments
    if type(name) ~= 'string' then
      error('name must be a string, got ' .. type_repr(name), 3)
    end

    if class_names[name] then
      error('name ' .. repr(name) .. ' is already in use', 3)
    end

    if type(deftable) ~= 'table' then
      error('deftable must be a table, got ' .. type_repr(deftable), 3)
    end

    for k, v in pairs(deftable) do
      if type(k) ~= 'string' then
        error('only string keys are allowed, got ' .. type_repr(k), 3)
      elseif prohibited_keys[k] then
        error('key ' .. repr(k) .. ' is prohibited to use', 3)
      elseif special_keys[k] and type(v) ~= special_keys[k] then
        error('key ' .. repr(k) .. ' must be a ' .. special_keys[k] .. ', got ' .. type_repr(v), 3)
      end
    end

    local parents = table.pack(...)
    local parent_class
    local parent_interfaces = {}
    for i = 1, parents.n do
      local p = parents[i]
      if isclass(p) then
        if parent_class then
          error('a class can have only one superclass, another superclass is passed as the '
            .. number2index(i) .. ' ancestor', 3)
        else
          parent_class = p
        end
      elseif isinterface(p) then
        table.insert(parent_interfaces, p)
      else
        error('all ancestors must be either classes or interfaces, the '
          .. number2index(i) .. ' passed ancestor is ' .. repr(p), 3)
      end
    end
    --endregion

    for _, itf in ipairs(parent_interfaces) do
      interface_prepare_class_deftable(itf, deftable, parent_class)
    end

    local class = {
      __name = name,
      -- indexers
      __public = {__class = true, __values = true},
      __readonly = {},
      __properties = {},
      -- inheritance
      __superclasses = {}, -- all ancestors, a set
      __interfaces = {}, -- all implemented interfaces, a set; may change over time
      __subclasses = {}, -- only direct descendants, an array
      __sub_metas = {}, -- metatables for indexers of direct descendants
      -- own instances
      __init = empty_function,
      __meta = {
        __len = instance_len,
        __index = instance_index,
        __newindex = instance_newindex,
        __pairs = instance_pairs,
        __metatable = true,
      },
    }
    local cls_meta = {
      __len = class_len,
      __newindex = class_newindex,
      __pairs = class_pairs,
      __tostring = class_tostring,
      __call = class_new_instance,
      __metatable = true,
    }

    for k, v in pairs(deftable) do
      if is_indexer(v) then
        class_key_initializers[v.type](class, k, v)
      else
        class[k] = v
      end
    end

    for _, indexer in ipairs(class_indexers) do
      class.__sub_metas[indexer] = {__index = class[indexer]}
    end

    local class_interfaces = class.__interfaces
    for _, itf in ipairs(parent_interfaces) do
      class_interfaces[itf] = true
      set_union(class_interfaces, itf.__all_ancestors)
    end

    local ins_meta = class.__meta
    if parent_class then

      class.__superclass = parent_class
      table.insert(parent_class.__subclasses, class)

      class.__superclasses[parent_class] = true
      set_union(class.__superclasses, parent_class.__superclasses)
      set_union(class_interfaces, parent_class.__interfaces)

      for _, indexer in ipairs(class_indexers) do
        setmetatable(class[indexer], parent_class.__sub_metas[indexer])
      end
      for metaname, metamethod in pairs(parent_class.__meta) do
        if not ins_meta[metaname] then
          ins_meta[metaname] = metamethod
        end
      end
      cls_meta.__index = parent_class

      if class.__init == empty_function then
        class.__init = parent_class.__init
      end
    end

    for metaname, metamethod in pairs(ins_meta) do
      if isNone(metamethod) then
        ins_meta[metaname] = nil
      end
    end

    known_classes[class] = true
    class_names[name] = class
    return setmetatable(class, cls_meta)
  end

  local package_class_meta = gen_pack_meta('Class')
  function package_class_meta.__call(_, ...) return create_class(...) end
  setmetatable(Class, package_class_meta)
  --endregion

  --region Interface variables
  --region Methods
  local signature_meta = gen_meta('signatures', true)
  signature_meta.__metatable = signature_meta

  function signature_meta:__tostring()
    return '<signature (' .. table.concat(self.arguments, ', ') .. ')>'
  end

  function signature_meta:__eq(other)
    return (self.has_vararg and other.has_vararg)
      or (self.has_vararg and #self.arguments - 1 <= #other.arguments)
      or (other.has_vararg and #self.arguments >= #other.arguments - 1)
      or #self.arguments == #other.arguments
  end

  local function signature_as_string(self)
    return '(' .. table.concat(self.arguments, ', ') .. ')'
  end

  local function define_signature(args)
    return setmetatable({
      arguments = args,
      has_vararg = args[#args] == '...',
    }, signature_meta)
  end

  local known_methods = setmetatable({}, __meta_weak_keys)
  local function is_method(v) return known_methods[v] or false end

  local function default_check_imp_absence(func)
    return type(func) ~= 'function'
  end

  local argument_name_pattern = "^[a-zA-Z_][a-zA-Z_0-9]*$"

  function Interface.Method(args, is_meta, default, check_imp_absence)
    if type(args) ~= 'string' then
      error('args must be a string, got ' .. type_repr(args), 2)
    end

    if type(is_meta) ~= 'boolean' then
      error('is_meta must be a boolean, got ' .. type_repr(is_meta), 2)
    end

    args = string.gsub(args, '%s*,%s*', ',')
    args = string_split(args, ',')

    for i, arg in ipairs(args) do
      if type(arg) ~= 'string' then
        error('arguments must be a string, got ' .. type_repr(arg), 2)
      elseif arg == '...' then
        if i ~= #args then
          error('vararg must be the last argument, got at the ' .. number2index(i) .. 'position, '
            .. #args .. ' positions total', 2)
        end
      elseif not string.match(arg, argument_name_pattern) then
        error('argument name must start with a letter or an underscore and '
          .. 'may contain letters, digits and underscores, got ' .. repr(arg), 2)
      end
    end

    if default ~= nil and type(default) ~= 'function' then
      error('default must be a function or nil, got ' .. type_repr(default), 2)
    end

    if check_imp_absence ~= nil and type(check_imp_absence) ~= 'function' then
      error('check_imp_absence must be a function or nil, got ' .. type_repr(check_imp_absence), 2)
    end

    local result = {
      args = args,
      is_meta = is_meta,
      default = default,
      check_imp_absence = check_imp_absence or default_check_imp_absence,
    }
    known_methods[result] = true
    return result
  end
  --endregion

  local interface_meta = gen_meta('interfaces', true)
  function interface_meta.__tostring(self) return '<interface ' .. repr(self.__name) .. '>' end

  local keys_of_method_tables = {'__usual_methods', '__metamethods'}

  local function interface_check_if_class_implements(self, cls)
    if cls.__interfaces[self] then return true end

    if self.__method_check_allowed then
      for m_name, m_table in pairs(self.__usual_methods) do
        if m_table.does_not_implement(cls[m_name]) then
          return false
        end
      end

      for m_name, m_table in pairs(self.__metamethods) do
        if m_table.does_not_implement(cls.__meta[m_name]) then
          return false
        end
      end

      cls.__interfaces[self] = true
      set_union(cls.__interfaces, self.__all_ancestors)
      return true
    end

    return false
  end

  local function interface_check_if_other_implements(self, other)
    if other.__all_ancestors[self] then return true end

    if self.__method_check_allowed then
      for _, key in ipairs(keys_of_method_tables) do
        local other_methods = other[key]

        for m_name, m_table in pairs(self[key]) do
          local other_method = other_methods[m_name]

          if not other_method or other_method.signature ~= m_table.signature then
            return false
          end
        end

      end

      other.__all_ancestors[self] = true
      set_union(other.__all_ancestors, self.__all_ancestors)
      return true
    end

    return false
  end

  local Class_meta = Class.meta

  function interface_prepare_class_deftable(self, class_deftable, class_parent)
    class_parent = class_parent or {__meta = {}}

    for m_name, m_table in pairs(self.__usual_methods) do
      local method = class_deftable[m_name] or class_parent[m_name]

      if m_table.does_not_implement(method) then
        if m_table.default then
          class_deftable[m_name] = m_table.default
        else
          error('any descendant of interface ' .. repr(self.__name) .. ' must implement '
            .. m_name .. signature_as_string(m_table.signature), 4)
        end
      end
    end

    for m_name, m_table in pairs(self.__metamethods) do
      local meta_field = class_deftable[m_name]
      local method

      if meta_field == nil then
        method = class_parent.__meta[m_name]
      else
        method = meta_field.value
      end

      if m_table.does_not_implement(method) then
        if m_table.default then
          class_deftable[m_name] = Class_meta(m_table.default)
        else
          error('any descendant of interface ' .. repr(self.__name) .. ' must implement metamethod '
            .. m_name .. signature_as_string(m_table.signature), 4)
        end
      end
    end

  end

  local function define_interface(name, allow_method_check, method_table, ...)
    --region Check arguments
    if type(name) ~= 'string' then
      error('name must be a string, got ' .. type_repr(name), 3)
    end

    if interface_names[name] then
      error('name ' .. repr(name) .. ' is already in use', 3)
    end

    if type(allow_method_check) ~= 'boolean' then
      error('allow_method_check must be a boolean, got ' .. type_repr(allow_method_check), 3)
    end

    if type(method_table) ~= 'table' then
      error('method_table must be a table, got ' .. type_repr(method_table), 3)
    end

    for k, v in pairs(method_table) do
      if type(k) ~= 'string' then
        error('only string keys are allowed, got ' .. type_repr(k), 3)
      elseif prohibited_keys[k] then
        error('key ' .. repr(k) .. ' is prohibited to use', 3)
      elseif not is_method(v) then
        error('method definition table must contain only methods, got '
          .. type_repr(v) .. ' as method with name ' .. repr(k), 3)
      end
    end

    local passed_parents = table.pack(...)
    local parents = {}
    for i = 1, passed_parents.n do
      local p = passed_parents[i]
      if isinterface(p) then
        table.insert(parents, p)
      else
        error('only interfaces can be ancestors of an interface, the '
          .. number2index(i) .. ' passed ancestor is ' .. repr(p), 3)
      end
    end
    --endregion

    local interface = {
      __name = name,
      __method_check_allowed = allow_method_check,
      __usual_methods = {},
      __metamethods = {},
      __all_ancestors = {},
      __direct_ancestors = parents,
    }

    local name2itf = {
      __usual_methods = {},
      __metamethods = {},
    }

    for k, m_table in pairs(method_table) do
      local key = m_table.is_metamethod and '__metamethods' or '__usual_methods'
      interface[key][k] = {
        signature = define_signature(m_table.args),
        default = m_table.default,
        does_not_implement = m_table.check_imp_absence,
      }
      name2itf[key][k] = name
    end

    local ancestors = interface.__all_ancestors

    for _, p in ipairs(parents) do

      -- Get methods from parents
      for _, k in ipairs(keys_of_method_tables) do
        local own = interface[k]
        local n2i = name2itf[k]

        for m_name, m_table in pairs(p[k]) do
          local own_m_table = own[m_name]

          if own_m_table then
            if own_m_table.signature ~= m_table.signature then
              error('method ' .. m_name .. signature_as_string(own_m_table.signature)
                .. ' from interface ' .. repr(n2i[m_name])
                .. ' conflicts with method ' .. m_name .. signature_as_string(m_table.signature)
                .. ' from interface ' .. repr(p.__name),
                3)
            end
          else
            own[m_name] = m_table
            n2i[m_name] = p.__name
          end

        end
      end

      -- Fill set of supers
      ancestors[p] = true
      set_union(ancestors, p.__all_ancestors)
    end

    known_interfaces[interface] = true
    interface_names[name] = interface
    return setmetatable(interface, interface_meta)
  end

  local package_interface_meta = gen_pack_meta('Interface')
  function package_interface_meta.__call(_, ...) return define_interface(...) end
  setmetatable(Interface, package_interface_meta)
  --endregion

  --region Common variables
  local function issubclass_get_supers(...)
    local supers = table.pack(...)
    local classes = {}
    local interfaces = {}

    for i = 1, supers.n do
      local other = supers[i]
      if isclass(other) then
        table.insert(classes, other)
      elseif isinterface(other) then
        table.insert(interfaces, other)
      else
        error('all ancestors must be either classes or interfaces, the '
          .. number2index(i) .. ' passed ancestor is ' .. repr(other), 3)
      end
    end

    return classes, interfaces
  end

  local function issubclass_class_case(cls, classes, interfaces)
    for _, other in ipairs(classes) do
      if cls == other or cls.__superclasses[other] then
        return true
      end
    end

    for _, other in ipairs(interfaces) do
      if interface_check_if_class_implements(other, cls) then
        return true
      end
    end

    return false
  end

  local function issubclass(value, ...)
    local classes, interfaces = issubclass_get_supers(...)
    if #classes == 0 and #interfaces == 0 then
      error('no ancestor is passed', 2)
    end

    if isclass(value) then
      return issubclass_class_case(value, classes, interfaces)
    end

    if isinterface(value) then
      for _, other in ipairs(interfaces) do
        if value == other or interface_check_if_other_implements(other, value) then
          return true
        end
      end

      return false
    end

    error('the first argument must be either a class or an interface, got ' .. repr(value), 2)
  end

  local function isinstance(ins, ...)
    if type(ins) == 'table' and isclass(ins.__class) then
      local classes, interfaces = issubclass_get_supers(...)
      if #classes == 0 and #interfaces == 0 then
        return true
      end
      return issubclass_class_case(ins.__class, classes, interfaces)
    end

    return false
  end
  --endregion

  --region Append to common package
  rawset(common, 'isclass', isclass)
  rawset(common, 'isinterface', isinterface)
  rawset(common, 'issubclass', issubclass)
  rawset(common, 'isinstance', isinstance)
  --endregion

  return Class, Interface
end
