function leef.table.weighted_randoms(tbl)
    local total_weight = 0
    local new_tbl = {}
    for i, v in pairs(tbl) do
        total_weight=total_weight+v
        table.insert(new_tbl, {i, v})
    end
    local ran = math.random()*total_weight
    --[[the point of the new table is so we can have them
    sorted in order of weight, so we can check if the random
    fufills the lower values first.]]
    table.sort(new_tbl, function(a, b) return a[2] > b[2] end)
    local scaled_weight = 0
    for i, v in pairs(new_tbl) do
        if (v[2]+scaled_weight) > ran then
            return v[1]
        end
        scaled_weight = scaled_weight + v[2]
    end
end
function leef.table.deep_copy(in_value, copy_metatable, copied_list)
    if not copied_list then copied_list = {} end
    if copied_list[in_value] then return copied_list[in_value] end
    if type(in_value)~="table" then return in_value end
    local out = {}
    copied_list[in_value] = out
    for i, v in pairs(in_value) do
        out[i] = leef.table.deep_copy(v, copy_metatable, copied_list)
    end
    if copy_metatable then
        setmetatable(out, getmetatable(in_value))
    end
    return out
end
function leef.table.contains(tbl, value)
    for i, v in pairs(tbl) do
        if v == value then
            return i
        end
    end
    return false
end
local function parse_index(i)
    if type(i) == "string" then
       return "[\""..i.."\"]"
    else
        return "["..tostring(i).."]"
    end
end
--dump() sucks.
local table_contains = leef.table.contains
function leef.table.tostring(tbl, shallow, list_length_lim, depth_limit, tables, depth)
    --create a list of tables that have been tostringed in this chain
    if not table then return "nil" end
    if not tables then tables = {this_table = tbl} end
    if not depth then depth = 0 end
    depth = depth + 1
    local str = "{"
    local initial_string = "\n"
    for i = 1, depth do
        initial_string = initial_string .. "    "
    end
    if depth > (depth_limit or math.huge) then
        return "(TABLE): depth limited reached"
    end
    local iterations = 0
    for i, v in pairs(tbl) do
        iterations = iterations + 1
        local val_type = type(v)
        if val_type == "string" then
            str = str..initial_string..parse_index(i).." = \""..v.."\","
        elseif val_type == "table" and (not shallow) then
            local contains = table_contains(tables, v)
            --to avoid infinite loops, make sure that the table has not been tostringed yet
            if not contains then
                tables[i] = v
                str = str..initial_string..parse_index(i).." = "..leef.table.tostring(v, shallow, list_length_lim, depth_limit, tables, depth)..","
            else
                str = str..initial_string..parse_index(i).." = "..tostring(v).." (index: '"..tostring(contains).."'),"
            end
        else
            str = str..initial_string..parse_index(i).." = "..tostring(v)..","
        end
    end
    if iterations >  (list_length_lim or math.huge) then
        return "(TABLE): too long, 100+ indices"
    end
    return str..string.sub(initial_string, 1, -5).."}"
end

local redact_field = "__redact_field"
function leef.table.fill(to_fill, replacement, copy_metatable, traversed)
    if replacement == redact_field then return nil end
    if type(replacement)~="table" then return replacement end
    if (not to_fill) or (replacement.__replace_old_table) or (to_fill.__replace_only) then return leef.table.deep_copy(replacement, copy_metatable, traversed) end
    if not traversed then traversed = {} end
    if traversed[replacement] then return traversed[replacement] end
    local out = {}
    traversed[replacement] = out
    for i, value in pairs(replacement) do
        out[i] = leef.table.fill(to_fill[i], value, copy_metatable, traversed)
        if type(out[i])=="table" then out[i].__replace_old_table = nil end
    end
    for i, v in pairs(to_fill) do
        if (not out[i]) and (not replacement[i]~=redact_field) then
            out[i] = leef.table.deep_copy(to_fill[i], copy_metatable, traversed)
        end
    end

    if copy_metatable then
        setmetatable(out, getmetatable(to_fill))
    end
    return out
end