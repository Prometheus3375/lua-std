function InitClassPackage(common)
  --region Initialization
  common = common or _ENV.common or _ENV.Common

  local __meta_weak_keys = {__mode = 'k'}
  local __meta_weak_values = {__mode = 'v'}

  local Class = {}
  local Interface = {}

  local known_classes = setmetatable({}, __meta_weak_keys)
  local known_interfaces = setmetatable({}, __meta_weak_keys)

  local function isclass(cls) return known_classes[cls] or false end

  local function isinterface(itf) return known_interfaces[itf] or false end

  local repr = common.repr
  local number2index = common.number2index
  local gen_meta = common.generate_protected_metatable
  local gen_pack_meta = common.generate_package_metatable
  --endregion

  --region Class variables
  function Class.typeof(ins)
    return ins.__class
  end

  function Class.nameof(cls)
    return cls.__name
  end

  function Class.addressof(ins)
    local meta = ins.__class.__meta
    local str = meta.__tostring
    local result
    if str then
      meta.__tostring = nil
      result = tostring(ins)
      meta.__tostring = str
    else
      result = tostring(ins)
    end

    return string.sub(result, string.len(meta.__name) + 3)
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

    error('instance of type ' .. cls.__name .. ' does not have a settable field ' .. repr(key), 3)
  end

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
    if not rawequal(value, nil) then
      return value
    end
    error('instance of type ' .. cls.__name .. ' does not have a gettable field ' .. repr(key), 3)
  end

  local function instance_newindex(self, key, value)
    newindex(self, self.__class, key, value)
  end

  local function instance_index(self, key)
    return index(self, self.__class, key)
  end

  local super_meta = gen_meta('super', false)

  function super_meta.__newindex(self, key, value)
    newindex(self.__ins, self.__cls, key, value)
  end

  function super_meta.__index(self, key)
    return index(self.__ins, self.__cls, key)
  end

  function super_meta.__tostring(self)
    return '<super: ' .. tostring(self.__cls) .. ', <' .. self.__ins.__class.__meta.__name .. '>>'
  end

  function Class.super(ins, parent)
    local cls = ins.__class
    if isclass(parent) then
      if not cls.__supers[parent] then
        error('class ' .. cls.__name .. ' does not have superclass ' .. parent.__name, 2)
      end
    elseif rawequal(parent, nil) then
      parent = cls.super
      if not parent then
        error('class ' .. cls.__name .. ' does not have a superclass', 2)
      end
    else
      error('second argument must be either a class or nil, got ' .. repr(parent), 2)
    end

    return setmetatable({__ins = ins, __cls = parent}, super_meta)
  end

  function Class.field(public)
    return {type = 'field', public = public}
  end

  function Class.property(getter, setter)
    if rawequal(getter, nil) and rawequal(setter, nil) then
      error('property must have either a getter or a setter or both', 2)
    end
    return {type = 'property', getter = getter, setter = setter}
  end

  function Class.meta(value)
    if rawequal(value, nil) then
      error('meta must have a value', 2)
    end
    return {type = 'meta', value = value}
  end

  local add_class_indexer = {
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

  local function class_tostring(cls)
    return '<class ' .. repr(cls.__name) .. '>'
  end

  local function new_instance(cls, ...)
    local self = {
      __class = cls,
      __values = {},
    }
    setmetatable(self, cls.__meta)
    cls.__init(self, ...)
    return self
  end

  local subclass
  local function empty_function() end

  local class_indexers = {
    '__public',
    '__readonly',
    '__properties',
    '__meta',
  }

  local special_fields = common.set({
    -- instance fields
    '__class',
    '__values',
    -- class fields
    '__name',
    '__public',
    '__readonly',
    '__properties',
    '__meta',
    '__init',
    'subclass',
    '__subs',
    '__sub_metas',
    'super',
    '__supers',
    -- meta for instances
    '__newindex',
    '__index',
    -- super fields
    '__ins',
    '__cls',
  })

  local default_instance_meta = {
    __len = function(self)
      error(self.__class.__name .. ' instances do not support length operator', 2)
    end,
    __ipairs = function(self)
      error(self.__class.__name .. ' instances do not support ipairs()', 2)
    end,
    __pairs = function(self)
      error(self.__class.__name .. ' instances do not support pairs()', 2)
    end,
  }

  local default_meta_of_instance_meta = {__index = default_instance_meta}

  local class_names = setmetatable({}, __meta_weak_values)

  function Class.GetByName(name) return class_names[name] end

  local function create_class(name, deftable, ...)
    --region Check arguments
    if class_names[name] then
      error('name ' .. repr(name) .. ' is already in use', 3)
    end

    local parents = table.pack(...)
    local parent_class
    local parent_interfaces = {}
    for i = 1, parents.n do
      local p = parents[i]
      if isclass(p) then
        if parent_class then
          error('a class can have only one superclass')
        else
          parent_class = p
        end
      elseif isinterface(p) then
        table.insert(parent_interfaces, p)
      else
        error('all ancestors must be either classes or interfaces, '
          .. number2index(i) .. ' passed ancestor is ' .. repr(p),
          3
        )
      end
    end
    --endregion

    for _, itf in ipairs(parent_interfaces) do
      itf:PrepareClassDeftable(deftable, parent_class, 4)
    end

    local class = {
      __name = name,
      __public = {},
      __readonly = {},
      __properties = {},
      __meta = setmetatable({
        __index = instance_index,
        __newindex = instance_newindex,
        __name = name .. ' instance',
        __metatable = true,
      }, default_meta_of_instance_meta),
      __subs = {},
    }
    local init = empty_function
    local meta = gen_meta('classes', true)
    meta.__tostring = class_tostring
    meta.__call = new_instance
    local sub_metas = {}
    local supers = {}

    for k, v in pairs(deftable) do
      if k == 'new' then
        init = v
      elseif special_fields[k] then
        error('field name ' .. repr(k) .. ' is prohibited to use inside a class', 3)
      elseif type(v) == 'table' and add_class_indexer[v.type] then
        add_class_indexer[v.type](class, k, v)
      else
        class[k] = v
      end
    end

    for _, k in ipairs(class_indexers) do
      sub_metas[k] = {__index = class[k]}
    end

    if parent_class then
      class.super = parent_class
      table.insert(parent_class.__subs, class)

      supers[parent_class] = true
      for p, _ in pairs(parent_class.__supers) do
        supers[p] = true
      end

      for _, k in ipairs(class_indexers) do
        setmetatable(class[k], parent_class.__sub_metas[k])
      end
      meta.__index = parent_class

      if rawequal(init, empty_function) then
        init = parent_class.__init
      end
    end

    class.__init = init
    class.new = new_instance
    class.subclass = subclass
    class.__sub_metas = sub_metas
    class.__supers = supers

    known_classes[class] = true
    for _, itf in ipairs(parent_interfaces) do
      itf:Register(class)
    end
    return setmetatable(class, meta)
  end

  subclass = function(parent, name, deftable, ...)
    return create_class(name, deftable, parent, ...)
  end

  local package_class_meta = gen_pack_meta('Class')
  function package_class_meta.__call(_, ...) create_class(...) end
  setmetatable(Class, package_class_meta)
  --endregion

  --region Interface variables
  local method_meta = gen_meta('interface methods', true)
  method_meta.__index = {}

  function method_meta.__tostring(self)
    if self.is_metamethod then
      return 'interface metamethod ' .. self.name .. self.signature
    end

    return 'interface method ' .. self.name .. self.signature
  end

  function method_meta.__eq(self, other)
    return self.name == other.name
      and self.signature == other.signature
      and self.is_metamethod == other.is_metamethod
  end

  function method_meta.__index:WithDefault(default)
    if rawequal(default, nil) or type(default) == 'function' then
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
    return setmetatable({
      name = name,
      signature = signature,
      is_metamethod = is_metamethod or false,
    }, method_meta)
  end

  local interface_meta = gen_meta('interfaces', true)
  function interface_meta.__tostring(self) return '<interface ' .. repr(self.__name) .. '>' end
  interface_meta.__index = {}

  function interface_meta.__index:Register(cls, err_level)
    if not isclass(cls) then
      error('only classes can be registered, got ' .. repr(cls), err_level or 2)
    end

    self.__registered[cls] = true
    for p, _ in pairs(self.__all_supers) do
      p.__registered[cls] = true
    end
  end

  function interface_meta.__index:HasRegistered(cls)
    return self.__registered[cls] or false
  end

  function interface_meta.__index:IsDescendantOf(itf)
    if rawequal(self, itf) then
      return true
    end

    return self.__all_supers[itf] or false
  end

  function interface_meta.__index:PrepareClassDeftable(class_deftable, class_parent, err_level)
    class_parent = class_parent or {__meta = {}}
    err_level = err_level or 2

    for _, m_table in ipairs(self.__simple_methods) do
      local m_name = m_table.name
      local method = class_deftable[m_name] or class_parent[m_name]

      if rawequal(method, nil) then
        if m_table.default then
          class_deftable[m_name] = m_table.default
        else
          error('any descendant of ' .. self.__name .. ' must implement '
            .. m_name .. m_table.signature, err_level)
        end
      elseif type(method) ~= 'function' then
        error('any descendant of ' .. self.__name .. ' must have ' .. m_name ..
          ' as a function with signature ' .. m_table.signature, err_level)
      end
    end

    for _, m_table in ipairs(self.__meta_methods) do
      local m_name = m_table.name
      local meta_field = class_deftable[m_name]
      local method

      if rawequal(meta_field, nil) then
        method = class_parent.__meta[m_name]
      else
        method = meta_field.value
      end

      if rawequal(method, nil) then
        if m_table.default then
          class_deftable[m_name] = Class.meta(m_table.default)
        else
          error('any descendant of ' .. self.__name .. ' must implement metamethod '
            .. m_name .. m_table.signature, 2)
        end
      elseif type(method) ~= 'function' then
        error('any descendant of ' .. self.__name .. ' must have ' .. m_name ..
          ' as a metamethod with signature ' .. m_table.signature, 2)
      end
    end

  end

  local interface_names = setmetatable({}, __meta_weak_values)

  function Interface.GetByName(name) return interface_names[name] end

  local function define_interface(name, methods, ...)
    --region Check arguments
    if interface_names[name] then
      error('name ' .. repr(name) .. ' is already in use', 3)
    end

    local passed_parents = table.pack(...)
    local parents = {}
    for i = 1, passed_parents.n do
      local p = passed_parents[i]
      if isinterface(p) then
        table.insert(parents, p)
      else
        error('only interfaces can be ancestors of an interface, '
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

    local supers_set = {}

    for _, p in ipairs(parents) do
      --region Get methods from parents
      local own_tables = {simple, meta}
      local p_tables = {p.__simple_methods, p.__meta_methods}

      for i = 1, 2 do
        local t, pt = own_tables[i], p_tables[i]

        for _, m_table in ipairs(pt) do
          local m_name = m_table.name
          local own_m_table = t.name2method[m_name]

          if own_m_table then
            if own_m_table ~= m_table then
              error(tostring(own_m_table) .. ' from ' .. t.name2interface[m_name]
                .. ' conflicts with ' .. tostring(m_table) .. ' from ' .. p.__name, 3)
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
      supers_set[p] = true
      for pp, _ in pairs(p.__all_supers) do
        supers_set[pp] = true
      end
      --endregion

    end

    local result = setmetatable({
      __name = name,
      __registered = setmetatable({}, __meta_weak_keys),
      __simple_methods = simple.methods,
      __meta_methods = meta.methods,
      __all_supers = supers_set,
      __direct_supers = parents,
    }, interface_meta)

    known_interfaces[result] = true
    return result
  end

  local package_interface_meta = gen_pack_meta('Interface')
  function package_interface_meta.__call(_, ...) define_interface(...) end
  setmetatable(Interface, package_interface_meta)
  --endregion

  --region Common variables
  local function issubclass_inner(value, ...)
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
        error('all ancestors must be either classes or interfaces, '
          .. number2index(i) .. ' passed ancestor is ' .. repr(other),
          3
        )
      end
    end

    if isclass(value) then
      for _, other in ipairs(classes) do
        if rawequal(value, other) or value.__supers[other] then
          return true
        end
      end

      for _, other in ipairs(interfaces) do
        if other:HasRegistered(value) then
          return true
        end
      end

      return false
    end

    if isinterface(value) then
      for _, other in ipairs(interfaces) do
        if value:IsDescendantOf(other) then
          return true
        end
      end

      return false
    end

    error('first argument must be either a class or an interface, got ' .. repr(value), 3)
  end

  local function issubclass(cls, ...)
    return issubclass_inner(cls, ...)
  end

  local function isinstance(ins, ...)
    return issubclass_inner(ins.__class, ...)
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
