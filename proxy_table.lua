
--- allows the creation of a "proxy" for a a real table which prevents modification while still following any changes to the original table.
--
-- This works with a given tree of tables.
-- be warned that these objects do not prevent the garbage collection of the table they are from. The table of origin (the one they are reproducing) can be accessed with the variable `__LEEF_PROXY_PARENT`.
-- this means you will **NEED TO KEEP A COPY** of whatever table you are protecting.
--
-- @module proxy_table

leef.class.proxy_table = {}
local proxy_table = leef.class.proxy_table


proxy_table.objects_by_proxy = {} --proxies indexed by their tables
local objects_by_proxy = proxy_table.objects_by_proxy
setmetatable(objects_by_proxy, {
    __mode = "v" --proxies wont be kept around if their tables dont exist. Since proxy tables themselves have weak keys AND values, this means that proxies will be released if their tables dont exist
})

local proxy_metatable = {
    __index = function(t, k)
        local real_value = objects_by_proxy[t][k]
        local value_type = type(real_value)
        if (value_type == "table") then
            local val = proxy_table.new(real_value)
            rawset(t, k, val)
            return val
        else
            return real_value
        end
    end,
    __newindex = function(t,l)
        error("attempt to modify proxy table")
    end,
    __mode = "kv"
}

--- create a new proxy table
-- @tparam table table to create immutable interface for
-- @return Proxy table
-- @function new
function proxy_table.new(table)
    assert(table~=proxy_table, "do not call leef.class.proxy_table functions as methods.")
    local proxy = {
        __LEEF_PROXY_PARENT = table,
    }
    setmetatable(proxy, proxy_metatable)
    objects_by_proxy[proxy] = table
    return proxy
end

--- check if its a proxy table
-- @param value value it check if proxy
-- @treturn bool
-- @function is_proxy
function proxy_table.is_proxy(value)
    if objects_by_proxy[value] then return true end
    return false
end


-- immoral overrides. that ill probably remove some day.
local old_ipairs = ipairs
local old_pairs = pairs

local function proxy_next(p, k)
    local original = objects_by_proxy[p]
    local next_key, _ = next(original, k) --value ignored as might be unsafe to return.
    return next_key, original[next_key] --get the value of the proxy that way if it's a table it is protected, and otherwise it will return the same thing.
end
--since next is modified we basically just return the normal pairs func.

local function iter(p, i)
    i = i + 1
    local t = objects_by_proxy[p]
    local v = t[i]
    if v then
      return i, v
    end
end
function pairs(...)
    local t = ...
    if objects_by_proxy[t] then
        return proxy_next, t, nil
    end
    return old_pairs(...)
end
function ipairs(...)
    local p = ...
    if objects_by_proxy[p] then
        return iter, p, 0
    else
        return old_ipairs(...)
    end
end

--[[local old_ipairs = ipairs
function ipairs(t, ...)
    return old_ipairs(proxies[t] or t, ...)
end]]