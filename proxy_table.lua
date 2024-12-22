--- immutable proxy tables for protection of variables.
--
-- WARNING: this is not technically a class, it is not based off `new_class`. And thus does not have an inherit or construct method.
-- the point of this module is to allow somebody to create a read only table based off of a normal lua table. Attempting to modify a proxy table will throw an error.
-- also note there is no good way to print this because tables are tied to their proxies independently, and then grabbed through the __index method rather then keeping a "working tree" of sub-tables.
-- This is apart of the [LEEF-class](https://github.com/Luanti-Extended-Engine-Features/LEEF-class) module.
--
-- subtables will belong to the first proxy structure that contains it, an unintended consequence of this is that destroying proxy tables that share proxys will likely result in the proxy table having
-- to be reinstantiated (automatically) on the next __index call for it. (While this is technically avoidable, it'd make things more complicated and this codebase is already messy.)
--
-- class is found as `leef.proxy_table`.
--
-- @classmod proxy_table

--- variable indicating the highest level table in the structure
--@field __proxy_table_parent

--- global variables
--@field proxies_by_tables a list of proxy tables indexed by their original tables
--@field tables_by_proxies a list of original tables indexed by their proxy tables
--@field proxy_children lists of children indexed by their highest level parent table. I.e. ```{ [parent_ref1] = {child_proxy1, child_proxy2},  [parent_ref2] = {...} }```
--@table leef.proxy_table

local Proxy_table = {
    proxies_by_tables = {},
    tables_by_proxies = {},
    proxy_children = {}
}
--setmetatable(Proxy_table.registered_proxies, {__mode="k"})
--setmetatable(Proxy_table.tables_by_proxies, {__mode="v"})
--setmetatable(Proxy_table.proxy_children, {__mode="k"})

leef.class.proxy_table = Proxy_table

--this creates proxy tables in a structure of tables
--this is great if you want to prevent the change of a table
--but still want it to be viewable, such as with constants
--og_table is the table which you want to be immutable. Parent is the parent proxy which it is apart of (this is optional and used for recursive parenting)
local tables_by_proxies = Proxy_table.tables_by_proxies
local metatable = {
    __index = function(t, key)
        local og_table = tables_by_proxies[t]
        if type(og_table[key]) == "table" then
            -- if the key is a table, then get_or_create a proxy for it
            return Proxy_table.get_or_create(og_table[key], og_table.__proxy_table_parent)
        else
            return og_table[key]
        end
    end,
    __newindex = function(table, key)
        assert(false, "attempt to edit immutable table, cannot edit a proxy table (LEEF-class)")
    end,
    __len = function(t)
        print("test")
        return #tables_by_proxies[t]
    end,
    __testvar=true
}

--- create a new proxy table
-- @param og_table original table
-- @param parent (optional) this is used internally to define which high level table a child proxy belongs to
-- @return proxy table
-- @function leef.proxy_table.new
function Proxy_table.new(og_table, parent)
    --the new proxy table
    local new = {
        __proxy_table_parent = parent
    }
    Proxy_table.proxies_by_tables[og_table] = new
    Proxy_table.tables_by_proxies[new] = og_table
    if parent then
        Proxy_table.proxy_children[parent][og_table] = new
    else
        Proxy_table.proxy_children[og_table] = {}
        parent = og_table
    end
    --set the proxy's metatable
    setmetatable(new, metatable)
    --[[overwrite og_table meta to destroy the proxy aswell (but I realized it wont be GCed unless it's removed altogether, so this is pointless)
    local mtable = getmetatable(og_table)
    local old_gc = mtable.__gc
    mtable.__gc = function(t)
        Proxy_table.registered_proxies[t] = nil
        Proxy_table.proxy_children[t] = nil
        old_gc(t)
    end
    setmetatable(og_table, mtable)]]

    --make children proxy tables
    for i, v in pairs(og_table) do
        if type(v) == "table" then
            Proxy_table.get_or_create(v, parent)
        end
    end
    return new
end

--- get (if it exists) or create a proxy table from an original
-- @param og_table original table
-- @param parent (optional) this is used internally to define which high level table a child proxy belongs to (if a new one is created.)
-- @return proxy table
function Proxy_table.get_or_create(og_table, parent)
    return Proxy_table.proxies_by_tables[og_table] or Proxy_table.new(og_table, parent)
end

--- removes all local references to the parent table, it's proxy, aswell as subtables and their proxies. This obviously will not GC unless the refs are cleared from all other variables globally.
-- @param parent the table/parent of subtables you wish to remove.
function Proxy_table.destroy_proxy(parent)
    Proxy_table.tables_by_proxies[Proxy_table.proxies_by_tables[parent]] = nil
    Proxy_table.proxies_by_tables[parent] = nil
    if Proxy_table.proxy_children[parent] then
        for i, v in pairs(Proxy_table.proxy_children[parent]) do
            Proxy_table.destroy_proxy(i)
        end
    end
    Proxy_table.proxy_children[parent] = nil
end


local proxies = Proxy_table.tables_by_proxies
local old_next = next
function next(t, i)
    return old_next(proxies[t] or t, i)
end
local old_pairs = pairs
function pairs(t, ...)
    return old_pairs(proxies[t] or t, ...)
end
local old_ipairs = ipairs
function ipairs(t, ...)
    return old_ipairs(proxies[t] or t, ...)
end