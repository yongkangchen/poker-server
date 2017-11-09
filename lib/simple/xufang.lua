local log = require "log"
local LERR = log.error
local LLOG = log.log
local msg = require "msg"
local timer = require "timer"

MSG_REG[msg.INVITE_PLAYER] = function(player)
	local up_room_player
	if player.xf and player.xf.up_room_player then
		up_room_player = player.xf.up_room_player
	else
		LERR("player.xf.up_room_player is nil, player is : %s", tostring(player.id))
		return
	end

    for _, role in ipairs(up_room_player) do
		local role_info = role.info
		if role.room and role.room.id then
			player:send(msg.REFUSE_INVITE, role.name, 1) 
			player.xf.refusal_tbl = {}
			player.xf.refusal_tbl[role.id] = {name = role.name, type = 1} 
		else
			role.xf = {}
			role.xf.is_inviter = {}
			role.xf.is_inviter = {room_id = player.room.id, invite_time = os.time() + 60, organizer = player}
		end
    end
	
	local invite_tbl = {}
	for _, role in pairs(up_room_player) do
		if role.xf and role.xf.is_inviter then
			table.insert(invite_tbl, role.id)
		end
	end
	
	local push_msg = require "login"
    push_msg(msg.INVITE_PLAYER, invite_tbl, player.room.id, 60)
	
	timer.add_timeout(60, function()
		for _, _role in ipairs(up_room_player) do
			if _role.xf and _role.xf.is_inviter then
				_role.xf = nil
				player:send(msg.REFUSE_INVITE, _role.name, 2) 
				player.xf.refusal_tbl = player.xf.refusal_tbl or {}
				player.xf.refusal_tbl[_role.id] = {name = _role.name, type = 2}
			end
		end
	end)
end

MSG_REG[msg.REFUSE_INVITE] = function(player, room_id)
	local player_id = player.id
	if not player.xf and not player.xf.is_inviter then
		LERR("The player has been rejected which default-time is over! player_id : %s", player.id)
		return
	end
	
	local organizer = player.xf.is_inviter.organizer
	
	player.xf = nil

	local room = organizer.room
	if not room or room.id ~= room_id then
		LERR("The sequel room has been delete! room_id is : %s", tostring(room_id))
		return
	end
	
	if #room.players == room.player_size then
		LERR("The sequel room is full!, room_id: %s", tostring(room_id))
		return
	end

	organizer:send(msg.REFUSE_INVITE, player.name, 2)
	
	organizer.xf.refusal_tbl = organizer.xf.refusal_tbl or {}
	organizer.xf.refusal_tbl[player_id] = {name = player.name, type = 2}
end

MSG_REG[msg.AGREE_INVITE] = function(player, room_id)
	if player.xf and player.xf.is_inviter then
		local organizer = player.xf.is_inviter.organizer
		local room = organizer.room
		player.xf = nil
		player:send(msg.AGREE_INVITE, not room or room.id ~= room_id) 
	end
end

local function renter(player)
	if player.xf and player.xf.refusal_tbl then
	    for _, tbl in pairs(player.xf.refusal_tbl) do
	        player:send(msg.REFUSE_INVITE, tbl.name, tbl.type)
	    end
	end
end

local function delete_data(player)
	if player.xf then
		player.xf = nil
	end
end

local function login(player)
	if player.xf and player.xf.is_inviter then
		player:send(msg.INVITE_PLAYER, player.xf.is_inviter.room_id, player.xf.is_inviter.invite_time - os.time())
	end
end

local function save_data (room)
    local hoster = room.host
    hoster.xf = {}
    hoster.xf.up_room_player = {}
    for _, role in ipairs(room.players) do
        if role ~= hoster then
            table.insert(hoster.xf.up_room_player, role)
        end
    end
end

return {
    save_data = save_data,
	renter = renter,
	delete_data = delete_data,
	login = login,
}