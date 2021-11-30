dofile('../Common.lua')

do
    local test = {}
    local common = InitCommon()
    local iter = common.iter
    local enumerate = common.enumerate

    local t = {10, 11, 12, 13, 14, 15 , 16, 17, 18, 19}
    t.__class = {}
    t.__name = 'table name'
    
    local function helper(state, value)
        state.current = state.current + 1
        if state.current <= state.n then
            return state.self[state.current]
        end
    end
    
    function t.__iter(self)
        return helper, {self = self, current = 0, n = #self}, 0
    end

    function test.iter()
        print('testing iter()')
        
        local i = 1
        for v in iter(t) do
            print(v)
            assert(i + 9 == v)
            i = i + 1
        end
        print('testing iter() - complete!') 
        
    end

    function test.enumerate()
        print('testing enumerate()')
        
        local i = 1
        for index, v in enumerate(t) do
            print(index, '-', v)
            assert(i + 9 == v)
            assert(i == index)
            i = i + 1
        end
        
        i = 1
        for index, v in enumerate(t, 5) do
            print(index, '-', v)
            assert(i + 9 == v)
            assert(i + 4 == index)
            i = i + 1
        end
        print('testing enumerate() - complete!') 
        
    end
    
    for k, v in pairs(test) do v() end
end