function InitAbstractCollections()
  local abc = {}

  local function def_method_with_default(self, default)
    return {
      name = self.name,
      signature = self.signature,
      default = default,
    }
  end

  local function def_method(name, signature)
    return {
      name = name,
      signature = signature,
      withDefault = def_method_with_default,
    }
  end

  -- todo: make def_method and def_interface public
  -- todo add lookup table generation
  -- todo add is<xxx> function generation, later add it to common
  -- todo: somehow merge iter, inext, etc. with this code
  local function def_interface(name, methods, ...)
    local method_names = {}
    local signatures = {}
    local defaults = {}
    local is_abstract = {}
    for i, v in ipairs(methods) do
      method_names[i] = v.name
      signatures[v.name] = v.signature
      if v.default then
        defaults[v.name] = v.default
      else
        is_abstract[v.name] = true
      end
    end

    local parents_prepare = {}
    for i, v in ipairs({...}) do
      parents_prepare[i] = v.prepare_class
    end

    local function prepare_class(cls_deftable)
      for _, m_name in ipairs(method_names) do
        local method = cls_deftable[m_name]

        if rawequal(method, nil) then
          if is_abstract[m_name] then
            error('any ' .. name .. ' must implement ' .. m_name .. signatures[m_name], 2)
          else
            cls_deftable[m_name] = defaults[m_name]
          end
        elseif type(method) ~= 'function' then
          error('any ' .. name .. ' must have ' .. m_name .. ' as a function with arguments '
            .. signatures[m_name], 2)
        end
      end

      for _, v in ipairs(parents_prepare) do v(cls_deftable) end

      -- todo return an array of lookup tables to fill
    end

    -- todo: add registering in lookup tables from common
    -- lookup tables must be returned from prepare_class
    local function create_class(cls_name, cls_deftable, cls_parent)

      prepare_class(cls_deftable)

      return Class(cls_name, cls_deftable, cls_parent)
    end

    abc[name] = create_class

    return {
      name = name,
      method_names = method_names,
      signatures = signatures,
      defaults = defaults,
      is_abstract = is_abstract,
      prepare_class = prepare_class,
      create_class = create_class,
    }
  end

  local method = {
    iter = def_method('__iter', '(self)'),
    inext = def_method('__inext', '(self)'),
  }

  local iterable = def_interface(
    'Iterable',
    {method.iter}
  )

  local function iterator_iter(self) return self end

  local iterator = def_interface(
    'Iterator', {
      method.iter:withDefault(iterator_iter),
      method.inext,
    },
    iterable
  )

  return abc
end
