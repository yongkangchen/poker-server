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
local timer = require "timer"

local LERR = log.error
local LLOG = log.log
local LTRACE = log.trace

local player_tbl = {}

local function get_player_data(player)
	return {
		id = player.id,
		name = player.name,
		sex = player.sex,
		cash_num = 0,
		coin_num = 0,
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

local push_msg_dict = {}

local function do_push_msg(player_id)
	local push_msg = push_msg_dict[player_id]
	if not push_msg then
		return
	end
	
    local player = player_tbl[player_id]
	
	local timeout = push_msg[1]
	if timeout < os.time() then
		push_msg_dict[player_id] = nil
		local pt = push_msg[2]
		MSG_REG[pt](player, false, unpack(push_msg, 3, table.maxn(push_msg)))
		return
	end
	
	if player and player.client then
		player:send(unpack(push_msg, 2, table.maxn(push_msg)))
	end
end

local function clear_push_msg()
	timer.add_timeout(10, function()
		local cur_time = os.time()
		for id, push_msg in pairs(push_msg_dict) do
			if push_msg[1] < cur_time then
				push_msg_dict[id] = nil
				local pt = push_msg[2]
				MSG_REG[pt](player_tbl[id], false, unpack(push_msg, 3, table.maxn(push_msg)))
			end
		end
		clear_push_msg()
	end)
end
clear_push_msg()

MSG_REG[msg.COMFIRM_MSG] = function(player, pt, ...)
	local player_id = player.id
	local push_msg = push_msg_dict[player_id]
	if not push_msg then
		return
	end
	push_msg_dict[player_id] = nil
	if pt ~= 69 then
		MSG_REG[pt](player, ...)
	end
end

local g_pid = 35450
MSG_REG[msg.LOGIN] = function(client, pid)
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
	
	player:send(msg.LOGIN, get_player_data(player), {}, "", false)
	do_push_msg(player.id)
    LLOG("login success, pid: %s", pid)
end

return function(player_id_tbl, timeout, pt, ...)
	if type(player_id_tbl) ~= "table" then
		player_id_tbl = {player_id_tbl}
	end
	
	for _, player_id in pairs(player_id_tbl) do
		push_msg_dict[player_id] = {timeout, pt, ...}
		do_push_msg(player_id)
	end
end
