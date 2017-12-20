#!/usr/local/bin/luajit

--[[
https://github.com/yongkangchen/poker-server

Copyright (C) 2016  Yongkang Chen lx1988cyk#gmail.com

GNU GENERAL PUBLIC LICENSE
   	Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.
--]]

local port = tonumber(arg[1])
local game_name = arg[2]

if not port or not game_name then
	print("usage: ./lib/main.lua port game_name")
	os.exit()
	return
end

local start = require "lib.start"

package.path = "./" .. game_name .. "/?.lua;" .. package.path

require "check_game"
require "room"(game_name)

start(port)