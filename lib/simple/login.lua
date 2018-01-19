--[[
https://github.com/yongkangchen/poker-server

Copyright (C) 2016  Yongkang Chen lx1988cyk#gmail.com

GNU GENERAL PUBLIC LICENSE
   	Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.
--]]

local msg = require "msg"
local log = require "log"

local LERR = log.error
local LLOG = log.log
local LTRACE = log.trace

local player_tbl = {}

local function get_player_data(player)
	return {
		id = player.id,
		name = player.name,
		sex = player.sex,
		room_id = player.room and player.room.id or nil,
	}
end

local function init_player(pid)
	local player_data = {}
	player_data.id = pid
	
	player_data.name = "test-" .. pid
	player_data.sex = 1
	
	player_data.send = function(self, pt, ...)
		LTRACE("send msg: 0x%08x, pid: %d, msg: %s,", pt, self.id, table.dump({...}))
		self.client:send(pt, ...)
	end
	player_data.recv = function() end
	return player_data
end

local function load_player(pid)
	if not pid then
		return
	end
	
	local player = player_tbl[pid]
	if not player then
		player = init_player(pid)
		player_tbl[pid] = player
	end
	return player
end

local g_pid = 35450
MSG_REG[msg.LOGIN] = function(client, pid, ...)
	if client.agent ~= client then
		LERR("repeat login, account pid : %s", client.agent.id)
		return
	end

    if not pid then
        pid = g_pid
		g_pid = g_pid + 1
        LLOG("create account success, pid: %s", pid)
    end
    
    local player = load_player(pid)
	if player.client then
		player.client:close()
	end
	
	player.client = client
	client.agent = player
	if test_on_login then
		test_on_login(player, ...)
	end

	player:send(msg.LOGIN, get_player_data(player), {}, "", false)
    LLOG("login success, pid: %s", pid)
end