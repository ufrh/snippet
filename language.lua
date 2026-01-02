local code = [[
{1}(<[1][101111]><[10]><[11][0]><[11]><[101111]><[11][0]>)
{2}(%1)
{3}(%<[^10111]><[10]><[1][11]><[1][11]><[1][10]><[ ]><[^11][111]><[1][10]><[1][10111]><[1][11]><[1111]>)
[=]
{1}(<[1][10]><[11][1]><[11][0]><[1][101]><[11][1]><[11][0]>)
{2}(%**{1})
[=]
!>
    @<[1][10]><[11][1]><[11][0]><[1][101]><[11][1]><[11][0]><[11][0]>
    ~{1}(<[1][10]><[11][1]><[11][0]><[1][101]><[11][1]><[11][0]>)
    ~{2}(%**{1})
<!
{1}(<[1][101111]><[10]><[11][0]><[11]><[101111]><[11][0]>)
{2}(%1)
{3}(%<[^10111]><[10]><[1][11]><[1][11]><[1][10]><[ ]><[^11][111]><[1][10]><[1][10111]><[1][11]><[1111]>)
[=]
{1}(t{1,11,111,1111,10,101,1011,10111,101111})
{2}(<[1][101111]><[1][101]><[1][11]><[101111]><[11][0]>)
{3}(%1,11,111,1111,10,101,1011,10111,101111)
{4}(%,)
[=]
{1}(<[1][10]><[11][1]><[11][0]><[1][101]><[11][1]><[11][0]>)
{2}(%t,<[1011]><[1][10111]>,1,3)
]]


local numericalrange = {
    ["1"] = "1",
    ["2"] = "11",
    ["3"] = "111",
    ["4"] = "1111",
    ["5"] = "10",
    ["6"] = "101",
    ["7"] = "1011",
    ["8"] = "10111",
    ["9"] = "101111",
    ["0"] = "0"
}

local alphabet = {
    ["a"] = "[1]",
    ["b"] = "[11]",
    ["c"] = "[111]",
    ["d"] = "[1111]",
    ["e"] = "[10]",
    ["f"] = "[101]",
    ["g"] = "[1011]",
    ["h"] = "[10111]",
    ["i"] = "[101111]",
    ["j"] = "[1][0]",
    ["k"] = "[1][1]",
    ["l"] = "[1][11]",
    ["m"] = "[1][111]",
    ["n"] = "[1][1111]",
    ["o"] = "[1][10]",
    ["p"] = "[1][101]",
    ["q"] = "[1][1011]",
    ["r"] = "[1][10111]",
    ["s"] = "[1][101111]",
    ["t"] = "[11][0]",
    ["u"] = "[11][1]",
    ["v"] = "[11][11]",
    ["w"] = "[11][111]",
    ["x"] = "[11][1111]",
    ["y"] = "[11][10]",
    ["z"] = "[11][101]",
    [" "] = "[ ]",
    [","] = ",",
    ["!"] = "!",
    ["."] = "."
}

local string = {}
function string.split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in inputstr:gmatch("([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function binarytostring(x)
    if x:find("!") then 
        local f = x:gsub("!", "")
        local found = false
        for _,v in pairs(numericalrange) do 
            if v == f then 
                return _
            end
        end
        return f
    elseif not x:find("!") then
        local str = ""
        local per = string.split(x, ">")
        for _,spl in pairs(per) do 
            local new = spl:gsub("<", "")
            local upper = false
            if new:find("%^") then
                new = new:sub(3, -1)
                upper = true
            end
            if new:sub(1, 1) ~= "[" then
                new = "[" .. new
            end
            for _,f in pairs(alphabet) do 
                if f == new then 
                    if upper then
                        str = str .. _:upper()
                    else
                        str = str .. _
                    end
                end
            end
        end
        return str
    end
end

local current_bit_states, global_bit_states, function_bit_states, subfunc_bit_state_default, global_return_bit_states = {
    [1] = "[]", [2] = "[]",
    [3] = "[]", [4] = "[]",
    [5] = "[]", [6] = "[]",
    [7] = "[]", [8] = "[]",
    [9] = "[]", [10] = "[]",
    [11] = "[]", [12] = "[]",
    [13] = "[]", [14] = "[]",
    [15] = "[]", [16] = "[]", 
}, {
    [1] = "[]", [2] = "[]",
    [3] = "[]", [4] = "[]",
    [5] = "[]", [6] = "[]",
    [7] = "[]", [8] = "[]",
    [9] = "[]", [10] = "[]",
    [11] = "[]", [12] = "[]",
    [13] = "[]", [14] = "[]",
    [15] = "[]", [16] = "[]", 
}, {
    [1] = "[]", [2] = "[]",
    [3] = "[]", [4] = "[]",
    [5] = "[]", [6] = "[]",
    [7] = "[]", [8] = "[]",
    [9] = "[]", [10] = "[]",
    [11] = "[]", [12] = "[]",
    [13] = "[]", [14] = "[]",
    [15] = "[]", [16] = "[]", 
}, {
    [1] = "[]", [2] = "[]",
    [3] = "[]", [4] = "[]",
    [5] = "[]", [6] = "[]",
    [7] = "[]", [8] = "[]",
}, {
    [1] = "[]", [2] = "[]",
    [3] = "[]", [4] = "[]",
    [5] = "[]", [6] = "[]",
    [7] = "[]", [8] = "[]",
}


local functions = {
    ["output"] = {
        binary = "<[1][10]><[11][1]><[11][0]><[1][101]><[11][1]><[11][0]>",
        func = function(x)
            if not x:find("%**") then
                local parsed = binarytostring(x)
                print(parsed)
            elseif x:find("!") then
                local parsed = binarytostring(x)
                print(parsed)
            elseif x:find("%**") then
                local bit = x:gsub("%**", ""):gsub("%{", "")
                if global_bit_states[bit]:find("<") and global_bit_states[bit]:find(">") then 
                    print(binarytostring(global_bit_states[bit]))
                else
                    print(global_bit_states[bit])
                end
            end
        end
    },
    ["setbit"] = {
        binary = "<[1][101111]><[10]><[11][0]><[11]><[101111]><[11][0]>",
        func = function(bit, val)
            for _,v in pairs(numericalrange) do 
                if v == bit then 
                    bit = _
                end
            end
            if val:find("%**") then
                local bit_ = val:gsub("%**", ""):gsub("%{", "")
                global_bit_states[bit_] = val
            else global_bit_states[bit] = val end
        end
    },
    ["setfbit"] = {
        binary = "<[1][101111]><[10]><[11][0]><[101]><[11]><[101111]><[11][0]>",
        func = function(bit, val)
            for _,v in pairs(numericalrange) do 
                if v == bit then 
                    bit = _
                end
            end
            function_bit_states[bit] = val
        end
    },
    ["resetbittable"] = {
        binary = "<[1][10111]><[10]><[1][101111]><[10]><[11][0]><[1][101111]><[11][0]><[1]><[11][0]><[10]><[1][101111]>",
        func = function(state)
            local parsed = binarytostring(state)
            local function reset(t)
                for index,bit in pairs(t) do 
                    bit = "[]"
                end
            end
            if parsed == "g" then 
                reset(global_bit_states)
            elseif parsed == "f" then 
                reset(function_bit_states)
            elseif parsed == "c" then 
                reset(current_bit_states)
            elseif parsed == "s" then 
                reset(subfunc_bit_state_default)
            elseif parsed == "gr" then 
                reset(global_return_bit_states)
            end
        end
    },
    ["split"] = {
        binary = "<[1][101111]><[1][101]><[1][11]><[101111]><[11][0]>",
        func = function(str, sep)
            local split = string.split(str, sep)
            local spl = {}
            for _,v in pairs(split) do
                local n;
                if tonumber(v) then 
                    n = v .. "!"
                end
                table.insert(spl, binarytostring(n))
            end
            local taken = false
            for _,v in ipairs(global_return_bit_states) do 
                if v == "[]" and not taken then 
                    taken = true 
                    global_return_bit_states[_] = spl
                end
            end
        end
    }
}

local Lines = string.split(code, "\n")

function ParseLine(Line)
    local index, j = Line:find("}")
    local bit = string.split(Line, "}")[1]:gsub("{", "")
    local instruction = Line:sub(index, #Line)
    
    instruction = instruction:gsub("%(", "")
    instruction = instruction:gsub("%)", "")
    instruction = instruction:gsub("}", "")
    
    return tonumber(bit), instruction
end

local arguments = {}

function Operate(Bits, arguments_)
    for _, bit in pairs(Bits) do 
        if type(bit) ~= 'table' and not bit:find("%%") then
            for index,function_ in pairs(functions) do 
                if bit == function_.binary then 
                    function_.func(table.unpack(arguments_))
                    arguments = {}
                end
            end
        end
    end
end

local fargs = {}

local isFunction = false
local fname = nil
local default = {table.unpack(subfunc_bit_state_default)}
local callarguments = {}
for _,Line in pairs(Lines) do 
    if not Line:find("%!>") then
        if isFunction then
            if Line:find("%~") then
                local LineP = Line:gsub("%~", "")
                local bit, instruction = ParseLine(LineP)
                default[bit] = instruction
                if instruction:find("%%") then 
                    local t = instruction:gsub("%%", "")
                    table.insert(fargs, t)
                end
            elseif Line:find("%@") then 
                local Name = Line:gsub("%@", "")
                fname = Name
                functions[binarytostring(fname)] = {
                    binary = fname:gsub("%s+", ""),
                    func = function()
                        Operate(default, fargs);
                    end
                }
            elseif Line:find("%#") then 
                local arg = Line:gsub("%#", "")
                global_bit_states[arg] = "[ ]"
            elseif Line:find("%<!") then 
                isFunction = false
            end  
        else
            if not Line:find("[=]") then 
                local bit, instruction = ParseLine(Line)
                if instruction:find("%t{") then 
                    local values = instruction:gsub("%t{", ""):gsub("%}", "")
                    local valuessplit = string.split(values, ",")
                    local bitcopy = {table.unpack(current_bit_states)}
                    for index,bit in pairs(bitcopy) do 
                        bitcopy[index] = valuessplit[index]
                    end
                    instruction = bitcopy
                end
                current_bit_states[bit] = instruction
                if type(instruction) == 'string' and instruction:find("%%") then 
                    local t = instruction:gsub("%%", "")
                    if t:find("t,") then 
                        local subtract = string.split(t, ",")
                        local bits, bit, index = binarytostring(subtract[2]), tonumber(subtract[3]), tonumber(subtract[4])
                        if bits == "g" then 
                            bits = global_bit_states
                        elseif bits == "f" then 
                            bits = function_bit_states
                        elseif bits == "c" then 
                            bits = current_bit_states
                        elseif bits == "s" then 
                            bits = subfunc_bit_state_default
                        elseif bits == "gr" then 
                            bits = global_return_bit_states
                        end
                        if tonumber(bits[bit][index]) then
                            t = bits[bit][index] .. "!"
                        else t = bits[bit][index] end
                    end
                    table.insert(arguments, t)
                end
        elseif Line:find("[=]") then
                Operate(current_bit_states, arguments);
            end
        end
    elseif Line:find("%!>") then
        isFunction = true
    end
end
