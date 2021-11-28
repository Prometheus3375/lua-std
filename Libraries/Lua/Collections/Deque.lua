function InitDeque()

    local function init_node(self, value)
        self.__values.value = value
    end

    local function node_Pop(self)
        -- removes connections of self
        local values = self.__values
        local prior = values.prior
        local subsq = values.subsq
        if prior then
            prior.__values.subsq = subsq
            values.prior = nil
        end
        if subsq then
            subsq.__values.prior = prior
            values.subsq = nil
        end
    end
    
    local function node_InsertAfter(self, node)
        -- inserts self after node
        local self_values = self.__values
        local node_values = node.__values
        local subsq = node_values.subsq
        if subsq then
            subsq.__values.prior = self
        end
        node_values.subsq = self
        self_values.prior = node
        self_values.subsq = subsq
    end
    
    local function node_InsertBefore(self, node)
        -- inserts self before node
        local self_values = self.__values
        local node_values = node.__values
        local prior = node_values.prior
        if prior then
            prior.__values.subsq = self
        end
        node_values.prior = self
        self_values.prior = prior
        self_values.subsq = node
    end
    
    local function node_tostring(self)
        return self.__name .. '(' .. self.value .. ')'
    end

    local DequeNode = Class('DequeNode', {
        -- fields
        prior = Class.field(false),
        subsq = Class.field(false),
        value = Class.field(false),
        -- methods
        new = init_node,
        Pop = node_Pop,
        InsertAfter = node_InsertAfter,
        InsertBefore = node_InsertBefore,
        -- meta
        __tostring = Class.meta(node_tostring),
    })
    
    local list_AppendNode
    
    local function init_list(self, ...)
        self.__values.length = 0
        local vals = table.pack(...)
        for i = 1, vals.n do
            list_AppendNode(self, DequeNode(vals[i]))
        end
    end
    
    local function list_AppendNodeRight(self, node)
        -- append node to the end of deque
        local values = self.__values
        local last = values.last
        
        if last then
            node_InsertAfter(node, last)
        else
            values.first = node
            values.last = node
        end
        
        values.length = values.length + 1
    end
    
    list_AppendNode = list_AppendNodeRight
    
    local function list_AppendNodeLeft(self, node)
        -- append node to the start of deque
        local values = self.__values
        local first = values.first
        
        if first then
            node_InsertBefore(node, first)
        else
            values.first = node
            values.last = node
        end
        
        values.length = values.length + 1
    end
    
    local function list_PopNode(self, node, err_level)
        local values = self.__values
        local length = values.length
    
        if length == 0 then
            error('pop from empty ' .. self.__name, err_level or 2)
        end
        
        local first = values.first
        local last = values.last
        local can_be_not_in_self = true
        
        if rawequal(node, first) then
            values.first = first.subsq
            can_be_not_in_self = false
        elseif rawequal(node, last) then
            values.last = last.prior
            can_be_not_in_self = false
        end
        
        if length <= 2 and can_be_not_in_self then
            error('the node does not belong to this ' .. self.__name, err_level or 2)
        end
        
        -- if this point reached and can_be_not_in_self is still false,
        -- assume self contains node
        node_Pop(node)
        length = length - 1
        values.length = length
        -- explicitly set pointers to nil if empty
        -- protects from incorrect linking between nodes
        if length == 0 then
            values.first = nil
            values.last = nil
        end
    end
    
    local function list_Clear(self)
        local values = self.__values
        
        values.length = 0
        values.first = nil
        values.last = nil
    end
    
    local function list_Concat(self, other, is_left)
        local self_values = self.__values
        local self_length = self_values.length
        local other_values = other.__values
        local other_length = other_values.length
        
        if other_length == 0 then return end
        
        if self_length == 0 then
            self_values.first = other_values.first
            self_values.last = other_values.last
            self_values.length = other_length
        else
            if is_left then
                node_InsertBefore(other_values.last, self_values.first)
                self_values.first = other_values.first
            else
                node_InsertAfter(other_values.first, self_values.last)
                self_values.last = other_values.last
            end
            self_values.length = self_length + other_length
        end
    end
    
    local function list_ConcatRight(self, other)
        -- concatenates other deque to the end of self
        -- it is better to clear other after the call
        list_Concat(self, other, false)
    end
    
    local function list_ConcatLeft(self, other)
        -- concatenates other deque to the start of self
        -- it is better to clear other after the call
        list_Concat(self, other, true)
    end
    
    local function list_AppendRight(self, value)
        local node = DequeNode(value)
        list_AppendNodeRight(self, node)
        return node
    end
    
    local function list_AppendLeft(self, value)
        local node = DequeNode(value)
        list_AppendNodeLeft(self, node)
        return node
    end
    
    local function list_PopRight(self)
        return list_PopNode(self, self.__values.last).value
    end
    
    local function list_PopLeft(self)
        return list_PopNode(self, self.__values.first).value
    end
    
    local function list_ExtendRight(self, other)
        -- todo
    end
    
    local function list_ExtendLeft(self, other)
        -- todo
    end
    
    local function list_tostring(self)
        -- todo
        return self.__name .. '()'
    end
    
    -- https://docs.python.org/3/library/collections.html#collections.deque
    -- todo: add len, concat https://www.lua.org/manual/5.3/manual.html#2.4
    local Deque = Class('Deque', {
        -- fields
        first = Class.field(false),
        last = Class.field(false),
        -- methods
        new = init_list,
        -- node methods
        AppendNodeRight = list_AppendNodeRight,
        AppendNodeLeft = list_AppendNodeLeft,
        PopNode = list_PopNode,
        ConcatRight = list_ConcatRight,
        ConcatLeft = list_ConcatLeft,
        -- common
        Clear = list_Clear,
        -- value methods
        AppendRight = list_AppendRight,
        AppendLeft = list_AppendLeft,
        PopRight = list_PopRight,
        PopLeft = list_PopLeft,
        ExtendRight = list_ExtendRight,
        ExtendLeft = list_ExtendLeft,
        -- shortcuts
        AppendNode = list_AppendNodeRight,
        Concat = list_ConcatRight,
        Append = list_AppendRight,
        Pop = list_PopRight,
        Extend = list_ExtendRight,
        -- meta
        __tostring = Class.meta(list_tostring),
    })
    
    return DequeNode, Deque
end
