if not leef then
    leef = {}
end
leef.class = {}

local path = minetest.get_modpath("leef_class")
dofile(path.."/proxy_table.lua")
dofile(path.."/New_Class.lua")