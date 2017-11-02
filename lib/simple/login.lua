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

local function push_msg_func(pt, player_id_tbl, ...)
	if type(player_id_tbl) ~= "table" then
		player_id_tbl = {player_id_tbl}
	end
	
	for _, player_id in pairs(player_id_tbl) do
		local player = player_tbl[player_id]
		if player and player.client then
			player:send(pt, ...)
		end
	end
end

MSG_REG[msg.INVITE_PLAYER] = function(player, invite_tbl)
	local tbl = table.copy(invite_tbl)
	if type(invite_tbl) ~= "table" then
		LERR("The content is not a table, invite_tbl is : %s", tostring(invite_tbl))
		return
	end
	
	for _, role_id in ipairs(tbl) do
		if not player_tbl[role_id] then
			LERR("The role is not in player_tbl, role_id is : %s", tostring(role_id))
			return
		end
	end

    for idx, id in ipairs(tbl) do
        local role = player_tbl[id]
		local role_info = get_player_data(role)
		if role_info.room_id then
			invite_tbl[idx] = nil
			player:send(msg.REFUSE_INVITE, role_info.name, 1) 
			player.refusal_tbl = player.refusal_tbl or {}
			player.refusal_tbl[id] = {name = role_info.name, type = 1} 
		else
			role.is_inviter = role.is_inviter or {}
			role.is_inviter = { organizer_id = player.id, room_id = player.room.id, invite_time = os.time() + 60}
		end
    end
    push_msg_func(msg.INVITE_PLAYER, invite_tbl, player.id, player.room.id, 60)
	
	local function build_func(up_room)
		return function ()
			if player.room ~= up_room then
				return 
			end
			for _, _id in ipairs(invite_tbl) do
				local _role =  player_tbl[_id]
				if _role.is_inviter then
					_role.is_inviter = nil
					player:send(msg.REFUSE_INVITE, _role.name, 2) 
					player.refusal_tbl = player.refusal_tbl or {}
					player.refusal_tbl[_id] = {name = player_tbl[_id].name, type = 2}
				end
			end
		end
	end
	local timeout_func = build_func(player.room)
	timer.add_timeout(60, timeout_func)
end

MSG_REG[msg.REFUSE_INVITE] = function(player, organizer_id, room_id)
	local player_id = player.id
	if not player.is_inviter then
		LERR("The player has been rejected which default-time is over! player_id : %s", player.id)
		return
	end
	
	player.is_inviter = nil
    local organizer = player_tbl[organizer_id]
	if not organizer then
		LERR("Organizer is not in player_tbl, organizer_id is : %s", tostring(organizer_id))
		return
	end
	
	local room = organizer.room
	if not room or room.id ~= room_id then
		LERR("The sequel room has been delete! room_id is : %s", tostring(room_id))
		return
	end
	
	if #room.players == room.player_size then
		LERR("The sequel room is full!, room_id: %s", tostring(room_id))
		return
	end

	organizer:send(msg.REFUSE_INVITE, player_tbl[player_id].name, 2)
	
	organizer.refusal_tbl = organizer.refusal_tbl or {}
	organizer.refusal_tbl[player_id] = {name = player_tbl[player_id].name, type = 2}

end

MSG_REG[msg.AGREE_INVITE] = function(player, organizer_id, room_id)
	if not player_tbl[organizer_id] then
		LERR("The organizer is not in player_tbl, organizer_id is : %s", tostring(organizer_id))
		return
	end
	
	local room = player_tbl[organizer_id].room
	player.is_inviter = nil
	player:send(msg.AGREE_INVITE, not room or room.id ~= room_id) 
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
    LLOG("login success, pid: %s", pid)
	
	if player.is_inviter then
		player:send(msg.INVITE_PLAYER,  player.is_inviter.organizer_id,  player.is_inviter.room_id, player.is_inviter.invite_time - os.time())
	end
end

-- return function(pt, player_id_tbl, ...)
-- 	if type(player_id_tbl) ~= "table" then
-- 		player_id_tbl = {player_id_tbl}
-- 	end
-- 	
-- 	for _, player_id in pairs(player_id_tbl) do
-- 		local player = player_tbl[player_id]
-- 		if player and player.client then
-- 			player:send(pt, ...)
-- 		end
-- 	end
-- end
