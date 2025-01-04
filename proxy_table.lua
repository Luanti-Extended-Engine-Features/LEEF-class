
--- allows the creation of a "proxy" for a a real table which prevents modification while still following any changes to the original table.
--
-- This works with a given tree of tables.
-- be warned that these objects do not prevent the garbage collection of the table they are from. The table of origin (the one they are reproducing) can be accessed with the variable `__LEEF_PROXY_PARENT`.
-- this means you will **NEED TO KEEP A COPY** of whatever table you are protecting.
--
-- @module proxy_table

leef.class.proxy_table = {}
local proxy_table = leef.class.proxy_table


proxy_table.tables_by_proxy = {} --proxies indexed by their tables
local tables_by_proxy = proxy_table.tables_by_proxy
setmetatable(tables_by_proxy, {
    __mode = "v" --proxies wont be kept around if their tables dont exist. Since proxy tables themselves have weak keys AND values, this means that proxies will be released if their tables dont exist
})

local proxy_metatable = {
    __index = function(t, k)
        local real_value = tables_by_proxy[t][k]
        local value_type = type(real_value)
        if ((value_type == "table") or (value_type == "class")) then
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
        __LEEF_PROXY_PARENT = table
    }
    setmetatable(proxy, proxy_metatable)
    tables_by_proxy[proxy] = table
    return proxy
end

local old_next = next
function next(p, k)
    local original = tables_by_proxy[p]
    if original then --if the table exists as an index here, it is a proxy.
        local next_key, _ = old_next(original, k) --value ignored as might be unsafe to return.
        return next_key, original[next_key] --get the value of the proxy that way if it's a table it is protected, and otherwise it will return the same thing.
    else
        return old_next(p,k)
    end
end
--since next is modified we basically just return the normal pairs func.
function pairs(t)
    return next, t, nil
end


local function iter(p, i)
    i = i + 1
    local t = tables_by_proxy[p]
    local v = t[i]
    if v then
      return i, v
    end
end
local old_ipairs = ipairs
function ipairs(p)
    if tables_by_proxy[p] then
        return iter, p, 0
    else
        return old_ipairs(p)
    end
end

--[[local old_ipairs = ipairs
function ipairs(t, ...)
    return old_ipairs(proxies[t] or t, ...)
end]]