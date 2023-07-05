function InitClasses()
    local function empty_func(...) end
    
    local function set(array)
        local s = {}
        for i, v in ipairs(array) do
            s[v] = true
        end
        return s
    end

    local special_fields = set({
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
        'super',
        '__supers',
        -- meta for instances
        '__newindex',
        '__index',
        -- super fields
        '__ins',
        '__cls',
    })
    
    local indexers = {
        '__public',
        '__readonly',
        '__properties',
    }

    local function typeof(ins)
        return ins.__class
    end
    
    local function nameof(cls)
        return cls.__name
    end
    
    
    local function newindex(self, cls, key, value)
        -- fallback for nil public fields
        if cls.__public[key] then
            rawset(self, key, value)
            return
        end
        -- setters
        local value = cls.__properties[key]
        if value then
            value.setter(self, value)
            return
        end
        
        error('instance of type ' .. cls.__name .. ' does not have settable key \'' .. key .. '\'', 3)
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
        if value then
            return value
        end
        error('instance of type ' .. cls.__name .. ' does not have gettable key \'' .. key .. '\'', 3)
    end
    
    local function instance_newindex(self, key, value)
        newindex(self, self.__class, key, value)
    end

    local function instance_index(self, key)
        return index(self, self.__class, key)
    end


    local function issubclass(cls, ...)
        local supers = table.pack(...)
        
        for i = 1, supers.n do
            local other = supers[i]
            if rawequal(cls, other) or cls.__supers[other] then
                return true
            end
        end
        return false
    end
    
    local function isinstance(ins, ...)
        return issubclass(ins.__class, ...)
    end
    
    
    local super_meta = {
        __newindex = function (self, key, value)
            newindex(self.__ins, self.__cls, key, value)
        end,

        __index = function (self, key)
            return index(self.__ins, self.__cls, key)
        end,
    }
    
    local function super(ins, parent)
        cls = ins.__class
        if parent then
            if not cls.__supers[parent] then
                error('class ' .. cls.__name .. ' does not have superclass ' .. parent.__name, 2)
            end
        else
            parent = cls.super
            if not parent then
                error('type ' .. cls.__name .. ' does not have a superclass', 2)
            end
        end
        
        return setmetatable({__ins = ins, __cls = parent}, super_meta)
    end
    
    
    local add_indexer = {
        field = function (cls, key, description)
            if description.public then
                cls.__public[key] = true
            else
                cls.__readonly[key] = true
            end
        end,
        
        property = function (cls, key, description)
            cls.__properties[key] = {
                getter = description.getter,
                setter = description.setter,
            }
        end,
        
        meta = function (cls, key, description)
            cls.__meta[key] = description.value
        end,
    }
    
    local function field(public)
        return {type = 'field', public = public}
    end
    
    local function property(getter, setter)
        if getter == nil and setter == nil then
            error('property must have either a getter or a setter or both', 2)
        end
        return {type = 'property', getter = getter, setter = setter}
    end
    
    local function meta(value)
        if value == nil then
            error('meta must have a value', 2)
        end
        return {type = 'meta', value = value}
    end
    
    -- todo: add repr for strings as in python
    local function class_tostring(cls)
        return '<class \'' .. cls.__name .. '\'>'
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
    
    -- todo: ensure all classes must have unique names
    -- todo: protect metatables of class and instances via __metatable
    local function create_class(name, deftable, parent)
        local class = {
            __name = name,
            __public = {},
            __readonly = {},
            __properties = {},
            __meta = {
                __newindex = instance_newindex,
                __index = instance_index,
                -- todo: add defult len, ipairs and pairs which throw an error
                -- Meta fields
                -- https://www.lua.org/manual/5.3/manual.html#2.4
                -- http://lua-users.org/wiki/MetatableEvents
            },
            __subs = {},
        }
        local init = empty_func
        local meta = {
            __tostring = class_tostring,
            __call = new_instance,
        }
        local supers = {}
        
        for k, v in pairs(deftable) do
            if k == 'new' then
                init = v
            elseif special_fields[k] then
                error(' key \''..key..'\' is prohibited to use inside a class', 3)
            elseif type(v) == 'table' and add_indexer[v.type] then
                add_indexer[v.type](class, k, v)
            else
                class[k] = v
            end
        end
        
        if parent then
            class.super = parent
            table.insert(parent.__subs, class)
            
            supers[parent] = true
            for p, _ in pairs(parent.__supers) do
                supers[p] = true
            end
            
            for i, k in ipairs(indexers) do
                setmetatable(class[k], {__index = parent[k]})
            end
            meta.__index = parent
            
            if init == empty_func then
                init = parent.__init
            end
        end
        
        class.__init = init
        class.new = new_instance
        class.subclass = subclass
        class.__supers = supers
        
        return setmetatable(class, meta)
    end
    
    subclass = function (parent, name, deftable)
        return create_class(name, deftable, parent)
    end

    local Class = {
        typeof = typeof,
        nameof = nameof,
        
        issubclass = issubclass,
        isinstance = isinstance,
        
        super = super,
    
        field = field,
        property = property,
        meta = meta,
    }
    
    setmetatable(Class, {
        __call = function (self, name, deftable, parent)
            return create_class(name, deftable, parent)
        end
    })
    
    return Class
end