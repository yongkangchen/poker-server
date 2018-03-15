local require_api = {
    "log", 
    "timer",
    "msg",
    "zphu"
}

--allow from ext.lua
local ext_api = [[
table.is_empty
table.copy
table.index
table.length
table.update
table.random
table.is_same_day
table.merge
table.dump
string.split
_G.check_hu
]]

local sandbox = require "sandbox"

local open_require = {}
for _, k in ipairs(require_api) do
    open_require[k] = sandbox.read_only(require(k), k)
end

ext_api:gsub('%S+', function(id)
    local module, method = id:match('([^%.]+)%.([^%.]+)')
    sandbox.set_env_method(module, method, _G[module][method])
end)

local game_path, game_loaded
local function game_require(name)
    local mod = open_require[name]
    if mod then
        return mod
    end
    
    mod = game_loaded[name]
    if mod then
        return mod
    end
    
    local path = game_path .. "/" .. name .. ".lua"
    local f = loadfile(path)
    assert(f, "module '" .. path .. "' not found")
    mod = sandbox.run(f)
    game_loaded[name] = mod
    return mod
end
sandbox.set_env("require", game_require)
sandbox.set_env("MSG_REG", setmetatable({}, {
    __index = MSG_REG,
    __newindex = function(_, pt, v)
        if MSG_REG[pt] ~= nil then
            error(string.format("duplicate MSG_REG, pt: 0x%08x", pt), 2) 
        end
        MSG_REG[pt] = v
    end
}))

return function(_game_name, _game_path)
    game_path = _game_path
    game_loaded = {}
    return game_require(_game_name)
end
