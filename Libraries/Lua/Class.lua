function typeof(obj)
    return obj.__class
end

function new (cls)
    return setmetatable({__values = {}, __class = cls}, cls.meta)
end

function str(cls)
    return 'Class ' .. cls.name
end

function newindex(self, cls, key, value)
    -- fallback for nil public fields
    if cls.public[key] then
        return rawset(self, key, value)
    end
    -- setters
    local callee = cls.setters[key]
    if callee then
        return callee(self, value)
    end
    
    error('object of type ' .. cls.name .. ' does not have settable key "' .. key .. '"')
end

function index(self, cls, key)
    -- fallback for nil public fields
    if cls.public[key] then
        return rawget(self, key)
    end
    -- readonly fields
    if cls.readonly[key] then
        return self.__values[key]
    end
    -- getters
    local callee = cls.getters[key]
    if callee then
        return callee(self)
    end
    -- methods
    callee = cls.methods[key]
    if callee then
        return callee
    end
    error('object of type ' .. cls.name .. ' does not have gettable key "' .. key .. '"')
end

super_meta = {
    __newindex = function (self, key, value)
        newindex(self.__obj, self.__cls, key, value)
    end,

    __index = function (self, key)
        return index(self.__obj, self.__cls, key)
    end,
}

function super(obj, parent)
    cls = obj.__class
    if parent then
        if not cls.__supers[parent] then
            error('type ' .. cls.name .. ' does not have parent type "' .. parent.name .. '"')
        end
    else
        parent = cls.supers[1]
        if not parent then
            error('type ' .. cls.name .. ' does not have a parent type')
        end
    end
    
    return setmetatable({__obj = obj, __cls = parent}, super_meta)
end

function Class(name, public, readonly, getters, setters, methods, meta, init, parent)
    local class = {...}

    -- check overlaps
    
    meta.__newindex = class_newindex
    meta.__index = class_index
    
    local class_meta = {__tostring = str}

    if parent then
        setmetatable(methods, {__index = parent.methods})
        -- ...
        local supers = {parent}
        local __supers = {parent = 0}
        
        for i, p in ipairs(parent.supers or {}) do
            supers[i + 1] = p
            __supers[p] = 0
        end
        
        class.supers = supers
        class.__supers = __supers
        
        class_meta.__index = parent
    else
        class.supers = {}
        class.__supers = {}
    end

    class.inherit = inherit
    class.new = function (cls, ...)
        local self = new(cls)
        init(self, ...)
        return self
    end
    
    setmetatable(class, class_meta}

    return class
end

function inherit(cls, name, public, readonly, getters, setters, methods, meta, init)
    return Class(public, name, readonly, getters, setters, methods, init, meta, cls)
end

function class_newindex(self, key, value)
    newindex(self, self.__class, key, value)
end

function class_index(self, key)
    return index(self, self.__class, key)
end

--[[
   local myclass = {}
   myclass.public_field = Class.field(true)
   myclass.readonly_field = Class.field(false)
   myclass.property = Class.property(getter, setter)
   myclass.readonly_property = Class.property(getter)
   myclass.method = Class.method(func)
   myclass.meta = Class.meta(value)
   
   return Class(myclass, 'myclass', ParentClass)
--]]
