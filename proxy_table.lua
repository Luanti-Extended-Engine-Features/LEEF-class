--
local Proxy_table = {
    registered_proxies = {},
    tables_by_proxies = {},
    proxy_children = {}
}
--setmetatable(Proxy_table.registered_proxies, {__mode="k"})
--setmetatable(Proxy_table.tables_by_proxies, {__mode="v"})
--setmetatable(Proxy_table.proxy_children, {__mode="k"})

mtul.class.proxy_table = Proxy_table
--this creates proxy tables in a structure of tables
--this is great if you want to prevent the change of a table
--but still want it to be viewable, such as with constants
--og_table is the table which you want to be immutable. Parent is the parent proxy which it is apart of (this is optional and used for recursive parenting)
local tables_by_proxies = Proxy_table.tables_by_proxies
local metatable = {
    __index = function(t, key)
        local og_table = tables_by_proxies[t]
        if type(og_table[key]) == "table" then
            return Proxy_table:get_or_create(og_table[key], og_table.__proxy_table_parent)
        else
            return og_table[key]
        end
    end,
    __newindex = function(table, key)
        assert(false, "attempt to edit immutable table, cannot edit a proxy table (MTUL-class)")
    end,
    __len = function(t)
        print("test")
        return #tables_by_proxies[t]
    end,
    __testvar=true
}

function Proxy_table:new(og_table, parent)
    local new = {
        __proxy_table_parent = parent
    }
    self.registered_proxies[og_table] = new
    self.tables_by_proxies[new] = og_table
    if parent then
        self.proxy_children[parent][og_table] = true
    else
        self.proxy_children[og_table] = {}
        parent = og_table
    end
    --set the proxy's metatable
    setmetatable(new, metatable)
    --[[overwrite og_table meta to destroy the proxy aswell (but I realized it wont be GCed unless it's removed altogether, so this is pointless)
    local mtable = getmetatable(og_table)
    local old_gc = mtable.__gc
    mtable.__gc = function(t)
        self.registered_proxies[t] = nil
        self.proxy_children[t] = nil
        old_gc(t)
    end
    setmetatable(og_table, mtable)]]
    --premake proxy tables
    for i, v in pairs(og_table) do
        if type(v) == "table" then
            Proxy_table:get_or_create(v, parent)
        end
    end
    return new
end
function Proxy_table:get_or_create(og_table, parent)
    return self.registered_proxies[og_table] or Proxy_table:new(og_table, parent)
end
function Proxy_table:destroy_proxy(parent)
    self.registered_proxies[parent] = nil
    if self.proxy_children[parent] then
        for i, v in pairs(self.proxy_children[parent]) do
            Proxy_table:destroy_proxy(i)
        end
    end
    self.proxy_children[parent] = nil
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