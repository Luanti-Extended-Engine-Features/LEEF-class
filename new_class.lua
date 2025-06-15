--- An instantiatable class to inherit for defining new instantiatable classes classes
-- the "base" class. To make a new class call `leef.class.new(def)` or `leef.class.new_class:new_class(def)`
-- Also note that these classes will not have the type `table` but instead `class` when `type(object)` is called.
-- This is apart of the [LEEF-class](https://github.com/Luanti-Extended-Engine-Features/LEEF-class) module
--
-- @classmod new_class
local objects = {}
setmetatable(objects, {
    __mode = 'kv' --allow garbage collection.
})
leef.class.new_class = {
    instance = false,
    --__no_copy = true
}


--TODO:
--make base classes protected by proxy and only moddable by the file they were declared in using debug library.
--allow


--- instance
-- @field instance defines wether the object is an instance, use this in construction to determine what changes to make

--- base_class
-- @field base_class only present for instances: the class from which this instance originates

--- parent_class
-- @field parent_class the class from which this class was inherited from

--- creates a new base class. Calls all constructors in the chain with def.instance=true. Can also be invoked by calling the class.
-- @param self the table which is being inherited (meaning variables that do not exist in the child, will read as the parent's). Be careful to remember that subtable values are NOT inherited, use the constructor to create subtables.
-- @param def the table containing the base definition of the class. This should contain a @{construct}
-- @return def a new base class
-- @function new_class
function leef.class.new_class:new_class(def)
    local t = type(def)
    if not (objects[def] or (t == "table")) then
        local info = debug.getinfo(2)
        error("class definition expected table, got `"..type(def).."` at class defined at "..info.short_src..":"..info.currentline)
    end
    --construction chain for inheritance
    --reminder that self is the parent class
    if not def.name then
        local info = debug.getinfo(2)
        minetest.log("warning", "LEEF new_class.lua: no name defined for class defined at "..info.short_src..":"..info.currentline)
        def.name = info.source..":"..info.currentline
    end
    objects[def] = "class"
    --if not def then def = {} else def = table.shallow_copy(def) end
    def.parent_class = self
    def.instance = false
    --def.__no_copy = true

    --this effectively creates a construction chain by overwriting .construct
    function def._construct(parameters)
        --rawget because in a instance it may only be present in a hierarchy but not the table itself
        if self._construct then
            self._construct(parameters)
        end
        if rawget(def, "construct") then
            def.construct(parameters)
        end
    end

    --legacy behavior is different.
    if not def._legacy_inherit then
        function def._construct_new_class(parameters)
            --rawget because in a instance it may only be present in a hierarchy but not the table itself
            if self._construct_new_class then
                self._construct_new_class(parameters)
            end
            if rawget(def, "construct_new_class") then
                def.construct_new_class(parameters)
            end
        end
    end

    --iterate through table properties
    setmetatable(def, {__index = self, __call = function(tbl, ...) tbl:new(...) end})

    if not def._legacy_inherit then
        if self._construct_new_class then
            self._construct_new_class(def, true)
        end
    else
        def._construct(def)
    end

    return def
end

---deprecated. The same as new_class, but has settings differences.
function leef.class.new_class:inherit(def)
    def._legacy_inherit = true
    self:new_class(def)
    return def
end

function leef.class.new(def)
    return leef.class.new_class:new_class(def)
end

--- checks if something is a class
-- @param value value
-- @treturn bool
-- @function leef.class.is_class
function leef.class.is_class(value)
    if objects[value] then return true end
    return false
end


--- Called when a child, grandchild, (and so on), instance or class is created. Check `self.instance` and `self.base_class` to determine what type of object it is.
-- every constructor from every parent is called in heirarchy (first to last).
-- use this to instantiate things like subtables or child class instances.
-- @param self the table (which would be def from new()).
-- @function construct


--- creates an instance of the base class. Calls all constructors in the chain with def.instance=true
-- @param def field for the new instance of the class. If fields are not present they will refer to the base class's fields (if present in the base class).
-- @return self a new instance of the class.
-- @function new
function leef.class.new_class:new(def)
    objects[def] = "class"
    --if not def then def = {} else def = table.shallow_copy(def) end
    def.base_class = self
    def.instance = true
    --def.__no_copy = true
    function def:new_class()
        assert(false, "cannot inherit instantiated object")
    end
    def.inherit = def.new_class
    setmetatable(def, {__index = self})
    --call the construct chain for inherited objects, also important this is called after meta changes
    self._construct(def)
    return def
end

--- (for printing) dumps the variables of this class
-- @param self
-- @tparam bool dump_classes whether to also print/dump classes.
-- @treturn string
-- @function dump
function leef.class.new_class:dump(dump_classes)
    local str = "{"
    for i, v in pairs(self) do
        if type(i) == "string" then
            str=str.."\n\t[\""..tostring(i).."\"] = "
        else
            str=str.."\n\t["..tostring(i).."] = "
        end
        if type(v) == "table" then
            local dumptable = dump(v):gsub("\n", "\n\t")
            str=str..dumptable
        elseif type(v) == "class" then
            if dump_classes then
                str = str..v:dump():gsub("\n", "\n\t")
            else
                str = str..tostring(v..":<"..v.name..">:"..((v.instance and "instance=true") or "instance=false"))
            end
        else
            str = str..tostring(v)
        end
    end
    return str.."\n}"
end
--[[local old_dump = dump
function dump(...)
    local t = ...
    if leef.class.is_class(t) then
        return t:dump()
    end
    return old_dump(...)
end]]


local old_type = type
local objects_by_proxy = leef.class.proxy_table.objects_by_proxy
function type(...)
    local a = ...
    if objects[a] then return objects[a] end
    if objects_by_proxy[a] then return type(objects_by_proxy[a]) end
    return old_type(...)
end