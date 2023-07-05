function InitClassPackage(common)
  --region Initialization
  common = common or _ENV.common or _ENV.Common

  local repr = common.repr
  local number2index = common.number2index
  local set2array = common.set2array
  local set_union = common.set_union
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
  -- todo add flag allow_numeric_indexes and keys for special functions to get and set them
  -- todo consider allowing using numeric indexes directly in self
  -- if yes, then allow Class.meta to accept nil
  -- todo remove default __ipairs, ipairs() uses __index by default

  function Class.field(public)
    return {type = 'field', public = public and true or false}
  end

  function Class.property(getter, setter)
    if getter == nil and setter == nil then
      error('property must have either a getter or a setter or both', 2)
    elseif getter ~= nil and type(getter) ~= 'function' then
      error('property getter must be a function, got ' .. repr(getter), 2)
    elseif setter ~= nil and type(setter) ~= 'function' then
      error('property setter must be a function, got ' .. repr(setter), 2)
    end
    return {type = 'property', getter = getter, setter = setter}
  end

  function Class.meta(value)
    if value == nil then
      error('meta must have a value', 2)
    end
    return {type = 'meta', value = value}
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
    -- fallback for nil public fields
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
    -- fallback for nil public fields
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
  local function class_ipairs() error('classes do not support ipairs()', 2) end
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

  local function instance_ipairs(self)
    error(repr(self.__class.__name) .. ' instance does not support ipairs()', 2)
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
  -- Thus, checks are added to __len, __ipairs and __pairs to emit correct errors.
  function super_meta:__len()
    local len = self.__class.__meta.__len
    if len == instance_len then
      error(repr(self.__class.__name) .. ' instance does not support length operator', 2)
    end

    return len(self.__ins)
  end

  function super_meta:__index(key)
    return index(self.__ins, self.__class, key)
  end

  function super_meta:__newindex(key, value)
    newindex(self.__ins, self.__class, key, value)
  end

  function super_meta:__ipairs()
    local ipairs = self.__class.__meta.__ipairs
    if ipairs == instance_ipairs then
      error(repr(self.__class.__name) .. ' instance does not support ipairs()', 2)
    end

    return ipairs(self.__ins)
  end

  function super_meta:__pairs()
    local pairs = self.__class.__meta.__pairs
    if pairs == instance_pairs then
      error(repr(self.__class.__name) .. ' instance does not support pairs()', 2)
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
    'subclass',
    '__superclass',
    '__superclasses',
    '__interfaces',
    '__subclasses',
    '__sub_metas',
    '__meta',
    '__init',
    -- meta keys for instances
    '__newindex',
    '__index',
    -- super keys
    '__ins',
    '__class',
  })

  local subclass
  local function empty_function() end
  local interface_prepare_class_deftable

  local function create_class(name, deftable, ...)
    --region Check arguments
    if type(name) ~= 'string' then
      error('name must be a string, got ' .. repr(name) .. ' of type ' .. type(name), 3)
    end

    if class_names[name] then
      error('name ' .. repr(name) .. ' is already in use', 3)
    end

    if type(deftable) ~= 'table' then
      error('definition table must be a table, got '
        .. repr(deftable) .. ' of type ' .. type(deftable), 3)
    end

    for k, _ in pairs(deftable) do
      if type(k) ~= 'string' then
        error('only string keys are allowed to use inside a class, got '
          .. tostring(k) .. ' of type ' .. type(k), 3)
      elseif prohibited_keys[k] then
        error('key ' .. repr(k) .. ' is prohibited to use inside a class', 3)
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
      __public = {},
      __readonly = {},
      __properties = {},
      -- inheritance
      subclass = subclass,
      __superclasses = {}, -- all ancestors, a set
      __interfaces = {}, -- all implemented interfaces, a set; may change over time
      __subclasses = {}, -- only direct descendants, an array
      __sub_metas = {}, -- metatables for indexers of direct descendants
      -- own instances
      new = class_new_instance,
      __meta = {
        __len = instance_len,
        __index = instance_index,
        __newindex = instance_newindex,
        __ipairs = instance_ipairs,
        __pairs = instance_pairs,
        __metatable = true,
      },
    }

    local init = empty_function
    local ins_meta = class.__meta
    local supers = class.__superclasses
    local interfaces = class.__interfaces
    local sub_metas = class.__sub_metas
    local cls_meta = {
      __len = class_len,
      __newindex = class_newindex,
      __ipairs = class_ipairs,
      __pairs = class_pairs,
      __tostring = class_tostring,
      __call = class_new_instance,
      __metatable = true,
    }

    for k, v in pairs(deftable) do
      if k == 'new' then
        init = v
      elseif type(v) == 'table' and class_key_initializers[v.type] ~= nil then
        class_key_initializers[v.type](class, k, v)
      else
        class[k] = v
      end
    end

    for _, indexer in ipairs(class_indexers) do
      sub_metas[indexer] = {__index = class[indexer]}
    end

    for _, itf in ipairs(parent_interfaces) do
      interfaces[itf] = true
      set_union(interfaces, itf.__all_ancestors)
    end

    if parent_class then
      class.__superclass = parent_class
      table.insert(parent_class.__subclasses, class)

      supers[parent_class] = true
      set_union(supers, parent_class.__superclasses)
      set_union(interfaces, parent_class.__interfaces)

      for _, indexer in ipairs(class_indexers) do
        setmetatable(class[indexer], parent_class.__sub_metas[indexer])
      end
      for metaname, metamethod in pairs(parent_class.__meta) do
        if not ins_meta[metaname] then
          ins_meta[metaname] = metamethod
        end
      end
      cls_meta.__index = parent_class

      if init == empty_function then
        init = parent_class.__init
      end
    end

    class.__init = init

    known_classes[class] = true
    class_names[name] = class
    return setmetatable(class, cls_meta)
  end

  subclass = function(cls, name, deftable, ...)
    return create_class(name, deftable, cls, ...)
  end

  local package_class_meta = gen_pack_meta('Class')
  function package_class_meta.__call(_, ...) return create_class(...) end
  setmetatable(Class, package_class_meta)
  --endregion

  --region Interface variables
  --region Methods

  -- todo add Signature object
  -- signatures are equal when one of them have vararg. Otherwise, number of arguments must be equal
  local method_meta = gen_meta('interface methods', true)
  method_meta.__index = {}

  function method_meta:__tostring()
    if self.is_metamethod then
      return '<interface metamethod ' .. self.name .. self.signature .. '>'
    end

    return '<interface method ' .. self.name .. self.signature .. '>'
  end

  function method_meta:__eq(other)
    return self.is_metamethod == other.is_metamethod
      and self.name == other.name
      and self.signature == other.signature
  end

  function method_meta.__index:WithDefault(default)
    if default == nil or type(default) == 'function' then
      return setmetatable({
        name = self.name,
        signature = self.signature,
        is_metamethod = self.is_metamethod,
        default = default,
      }, method_meta)
    end

    error('default must be a function or nil, got ' .. repr(default), 2)
  end

  function Interface.DefineMethod(name, signature, is_metamethod)
    -- todo check that name is not in prohibited_keys
    -- todo check that signature is string
    return setmetatable({
      name = name,
      signature = signature,
      is_metamethod = is_metamethod and true or false,
    }, method_meta)
  end
  --endregion

  local interface_meta = gen_meta('interfaces', true)
  function interface_meta.__tostring(self) return '<interface ' .. repr(self.__name) .. '>' end

  local keys_of_method_tables = {'__simple_methods', '__meta_methods'}

  local function interface_check_if_class_implements(self, cls)
    if cls.__interfaces[self] then return true end

    if self.__method_check_allowed then
      for _, m_table in ipairs(self.__simple_methods) do
        if type(cls[m_table.name]) ~= 'function' then
          return false
        end
      end

      for _, m_table in ipairs(self.__meta_methods) do
        if type(cls.__meta[m_table.name]) ~= 'function' then
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
        local name2method = {}
        for _, m_table in ipairs(other[key]) do
          name2method[m_table.name] = m_table
        end

        for _, m_table in ipairs(self[key]) do
          if m_table ~= name2method[m_table.name] then
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
  interface_prepare_class_deftable = function(self, class_deftable, class_parent)
    class_parent = class_parent or {__meta = {}}

    for _, m_table in ipairs(self.__simple_methods) do
      local m_name = m_table.name
      local method = class_deftable[m_name] or class_parent[m_name]

      if method == nil then
        if m_table.default then
          class_deftable[m_name] = m_table.default
        else
          error('any descendant of interface ' .. repr(self.__name) .. ' must implement '
            .. m_name .. m_table.signature, 4)
        end
      elseif type(method) ~= 'function' then
        error('any descendant of interface ' .. repr(self.__name) .. ' must have ' .. m_name ..
          ' as a function with signature ' .. m_table.signature, 4)
      end
    end

    for _, m_table in ipairs(self.__meta_methods) do
      local m_name = m_table.name
      local meta_field = class_deftable[m_name]
      local method

      if meta_field == nil then
        method = class_parent.__meta[m_name]
      else
        method = meta_field.value
      end

      if method == nil then
        if m_table.default then
          class_deftable[m_name] = Class_meta(m_table.default)
        else
          error('any descendant of interface ' .. repr(self.__name) .. ' must implement metamethod '
            .. m_name .. m_table.signature, 4)
        end
      elseif type(method) ~= 'function' then
        error('any descendant of interface ' .. repr(self.__name) .. ' must have ' .. m_name ..
          ' as a metamethod with signature ' .. m_table.signature, 4)
      end
    end

  end

  local function define_interface(name, allow_method_check, methods, ...)
    --region Check arguments
    if type(name) ~= 'string' then
      error('name must be a string, got ' .. repr(name) .. ' of type ' .. type(name), 3)
    end

    if interface_names[name] then
      error('name ' .. repr(name) .. ' is already in use', 3)
    end

    if type(methods) ~= 'table' then
      error('method definition table must be a table, got '
        .. repr(methods) .. ' of type ' .. type(methods), 3)
    end

    -- todo check that methods content are all methods
    -- using m_table.WithDefault == method_meta.__index.WithDefault

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

    local simple = {
      methods = {},
      name2method = {},
      name2interface = {},
    }
    local meta = {
      methods = {},
      name2method = {},
      name2interface = {},
    }
    for _, m_table in ipairs(methods) do
      local t = m_table.is_metamethod and meta or simple
      table.insert(t.methods, m_table)
      t.name2method[m_table.name] = m_table
      t.name2interface[m_table.name] = name
    end

    local ancestors = {}

    local own_tables = {simple, meta}
    local method_type = {'method ', 'metamethod '}
    for _, p in ipairs(parents) do
      --region Get methods from parents
      local p_tables = {p.__simple_methods, p.__meta_methods}

      for i = 1, 2 do
        local t, pt, typ = own_tables[i], p_tables[i], method_type[i]

        for _, m_table in ipairs(pt) do
          local m_name = m_table.name
          local own_m_table = t.name2method[m_name]

          if own_m_table then
            if own_m_table ~= m_table then
              error(typ .. m_name .. own_m_table.signature
                .. ' from interface ' .. repr(t.name2interface[m_name]) .. ' conflicts with '
                .. typ .. m_name .. m_table.signature
                .. ' from interface ' .. repr(p.__name),
                3)
            end
          else
            table.insert(t.methods, m_table)
            t.name2method[m_name] = m_table
            t.name2interface[m_name] = p.__name
          end
        end

      end
      --endregion

      --region Fill set of supers
      ancestors[p] = true
      set_union(ancestors, p.__all_ancestors)
      --endregion

    end

    local result = setmetatable({
      __name = name,
      __method_check_allowed = allow_method_check and true or false,
      __simple_methods = simple.methods,
      __meta_methods = meta.methods,
      __all_ancestors = ancestors,
      __direct_ancestors = parents,
    }, interface_meta)

    known_interfaces[result] = true
    interface_names[name] = result
    return result
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

    if supers.n == 0 then
      error('no ancestor is passed', 3)
    end

    for i = 1, supers.n do
      local other = supers[i]
      if isclass(other) then
        table.insert(classes, other)
      elseif isinterface(other) then
        table.insert(interfaces, other)
      else
        error('all ancestors must be either classes or interfaces, the'
          .. number2index(i) .. ' passed ancestor is ' .. repr(other),
          3
        )
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

    error('the first argument must be either a class or an interface, got ' .. repr(value), 3)
  end

  local function isinstance(ins, ...)
    if type(ins) == 'table' and isclass(ins.__class) then
      return issubclass_class_case(ins.__class, issubclass_get_supers(...))
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
