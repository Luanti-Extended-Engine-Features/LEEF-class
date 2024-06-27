local path = minetest.get_modpath("mtul_class")
dofile(path.."/proxy_table.lua")
dofile(path.."/new_class.lua")

if not mtul then
    mtul = {}
end
mtul.class = {}