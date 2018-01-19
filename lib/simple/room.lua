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
local timer = require "timer"

local visit = require "visit"
local broadcast_visit = visit.broadcast_visit
local get_visit_info = visit.get_visit_info
local clean_visit_role = visit.clean_visit_role
local add_visit_role = visit.add_visit_role
local del_visit_role = visit.del_visit_role
local visit_is_full = visit.is_full

local game
local game_name
local game_id = GAME_ID

local ROOM_MAX_ID = 999999
local room_tbl = {}

local function broadcast(room, ...)
    for _, role in pairs(room.players) do
        role:send(...)
    end

    broadcast_visit(room, ...)

    if room.playback then
        table.insert(room.playback, table.dump{...})
    end
end

local function broadcast_all(room, ...)
    broadcast(room, ...)
    for _, role in pairs(room.mid_players) do
        role:send(...)
    end
end

local function init_msg(player, distance, idx, is_zhuang, is_visit)
    local player_info = player.info
    local hand = player_info.hand
    if hand and (distance ~= 0 or is_visit) then   --客户端判断会导致可以看牌
        hand = #hand
    end

    local data = {
        id = player.id,
        name = player.name,
        idx = idx,
        ip = "",
        sex = player.sex,
        hand = hand,
        out = player_info.out,
        is_ready = player_info.is_ready,
        score = player_info.result.total_score,
        is_zhuang = is_zhuang,
        is_mid_enter = player_info.is_mid_enter,
    }

    local set_init_msg = game.set_init_msg
    if set_init_msg then
        set_init_msg(player, data, player.room)
    end
    return msg.INIT, data, distance
end

--TODO: 客户端is_visitor的标志
local function get_room_data(room)
    local data = room.create_data
    if data then
        data = table.copy(data)
    else
        data = {}
    end
    data.id = room.id
    data.round = room.round
    data.max_round = room.max_round
    data.player_size = room.player_size
    data.host_id = room.host.id
    data.start_count = room.start_count
    data.game_name = game_name
    data.gaming = room.gaming
    if game.init_room_data then
        game.init_room_data(room, data)
    end

    return data
end

local function delete_room(room)
    clean_visit_role(room, room.is_dismiss and msg.DISMISS or nil)
    for _, role in pairs(room.players) do
        role.room = nil
    end
    room_tbl[room.id] = nil
end

local function init_playback(room)
    room.playback = {
        table.dump{msg.CREATE, room:get_data()}
    }
    for i, role in pairs(room.players) do
        table.insert(room.playback, table.dump{init_msg(role, 0, i)})
    end
end

local function start_game(room)
    room.start_count = room.start_count + 1
    room.gaming = true
    game.start_room(room)
    init_playback(room)
end

local function end_game(room, ...)
    room.can_out = false
    room.gaming = false

    room.round = room.round + 1
    room.ready_count = 0

    room.idx = room.next_start_idx or room.idx

    local is_over
    if room.is_over == nil then
        is_over = room.round > room.max_round
    else
        is_over = room.is_over
    end
    if room.is_dismiss then
        is_over = true
    end

    local cur_time = os.time()
    local result = game.get_result(room, is_over, ...)
    if result then
        result = table.copy(result)
        room:broadcast_all(msg.RESULT, result, is_over, room.is_dismiss)

        for idx in pairs(room.players) do
            if result[idx] and result[idx].result then
                result[idx].result = nil
                result[idx].time = cur_time
            end
        end
        room.one_result[room.round - 1] = result
    end

    room.playback = nil

    room.history_time = room.history_time or cur_time
    room.history_save = room.history_save or {}

    local battle_tbl = {}
    battle_tbl.room_id = room.id
    battle_tbl.type = room.type
    battle_tbl.game_name = game_name
    battle_tbl.max_round = room.max_round
    battle_tbl.time = room.history_time
    battle_tbl.total_result = {}
    battle_tbl.one_result = {}
    for _, role in pairs(room.players) do
        table.insert(battle_tbl.total_result, {
            host = role == room.host,
            pid = role.id,
            name = role.name,
            total_score = role.info.result.total_score,
        })
    end

    for round, one_result in ipairs(room.one_result) do
        local tbl = {}
        battle_tbl.one_result[round] = tbl
        for _, v in pairs(one_result) do
            table.insert(tbl, {
                host = v.is_host,
                pid = v.id,
                name = v.name,
                add_score = v.add_score,
            })
        end
    end

    for _, role in pairs(room.players) do
        if not room.history_save[role.id] then
            room.history_save[role.id] = true
        end
    end

    for idx, role in pairs(room.mid_players) do
        role.info.is_mid_enter = nil
        room.players[idx] = role
        if is_over then
            role:send(msg.DISMISS)
        end
    end

    room.mid_players = {}
    if is_over then
        room:delete()
    end
end

MSG_REG[msg.CREATE] = function(player, _, create_tbl, num, ...)
    if num ~= game.BASE_ROUND and num ~= game.BASE_ROUND * 2 and (not game.BASE_COUNT or num ~= game.BASE_ROUND * 3) then
        LERR("create_room failed, invalid num: %d, pid: %d", num, player.id)
        return
    end

    if player.room then
        LERR("create_room failed, alread in room: %d, pid: %d", player.room.id, player.id)
        player:send(msg.CREATE, 1)
        return
    end

    local room = game.create_room(player, ...)
    if not room then
        player:send(msg.CREATE)
        return
    end

    local room_gid = math.random(100000, ROOM_MAX_ID)
    while room_tbl[room_gid] do
        room_gid = math.random(100000, ROOM_MAX_ID)
    end

    room_tbl[room_gid] = room

    room.id = room_gid
    room.round = 1
    room.max_round = num
    room.players = {player}
    room.ready_count = 0
    room.mid_players = {}
    room.visit_players = {}
    room.start_count = 0
    room.host = player
    room.one_result = {}
    room.dismiss_tbl = {}
    room.dismiss_time = nil
    room.money_type = type(create_tbl) == "table" and create_tbl.money_type or create_tbl

    room.broadcast = broadcast
    room.broadcast_all = broadcast_all
    room.get_data = get_room_data
    room.delete = delete_room
    room.end_game = end_game
    room.init_msg = init_msg

    player.room = room
    player.game_id = game_id
    player.info = game.create_info(nil, room, true)

    player:send(msg.CREATE, room:get_data())

    player:send(init_msg(player, 0, 1)) --FIXME: 不确定是否影响其他游戏

    --require "gd_robot"(room_gid)
    LLOG("create room success, room_id: %d, pid: %d", room_gid, player.id)

end

MSG_REG[msg.READY] = function(player, is_ready)
    local room = player.room
    if not room then
        LERR("ready failed, not in room, pid: %d", player.id)
        return
    end

    if room.gaming then
        LERR("ready failed, is gaming, room_id: %d, pid: %d", room.id, player.id)
        return
    end

    is_ready = is_ready == true

    local player_info = player.info
    if player_info.is_ready == is_ready then
        LERR("ready failed, same state, pid: %d", player.id)
        return
    end

    player_info.is_ready = is_ready

    local ready_count
    if is_ready then
       ready_count = room.ready_count + 1
    else
       ready_count = room.ready_count - 1
    end
    room.ready_count = ready_count

    room:broadcast(msg.READY, player.id, is_ready, ready_count)

    if ready_count == room.player_size then
        start_game(room)
    elseif game.CAN_MID_ENTER and room.round > 1 and ready_count == table.length(room.players) then
        start_game(room)
    end

    LLOG("ready success, room_id: %d, ready_count: %d, pid: %d", room.id, ready_count, player.id)
end

MSG_REG[msg.START_GAME] = function(player)
    local room = player.room
    if not room then
        LERR("start game failed, not in room, pid: %d", player.id)
        return
    end

    if room.start_count ~= 0 then
        LERR("already started, room_id: %d, pid: %d", room.id, player.id)
        return
    end

    if room.gaming then
        LERR("start game failed, is gaming, room_id: %d, pid: %d", room.id, player.id)
        return
    end

    if room.host ~= player then
        LERR("start game failed, player is not host, room_id: %d, pid: %d", room.id, player.id)
        return
    end

    if room.ready_count ~= table.length(room.players) then
        LERR("start game failed, not all ready, room_id: %d, pid: %d", room.id, player.id)
        return
    end

    if room.ready_count < 2 then
        LERR("start game failed, ready_count < 2, room_id: %d, pid: %d", room.id, player.id)
        return
    end

    start_game(room)
end

local function should_ask(room)
    local is_full
    local count = table.length(room.players) + table.length(room.mid_players)
    if count >= room.player_size or (room.max_player_size and count >= room.max_player_size) then
        is_full = true
    end

    local can_mid_enter = false
    if game.CAN_MID_ENTER then
        can_mid_enter = not is_full
    end

    local can_visitor = game.CAN_VISIT and not visit_is_full(room)

    local ask_data
    if can_visitor or can_mid_enter then
        ask_data = {
            can_visitor = can_visitor,
            can_mid_enter = can_mid_enter
        }
    end

    if ask_data and (room.start_count > 0 or is_full) then
        return true, ask_data, is_full
    end
    return false, ask_data, is_full
end

local function send_ask(room, player, ask_data)
    local room_data = {
        room_id = room.id,
        names = {},
    }

    room_data.round_count = room.max_round - room.start_count

    room_data.need_cash = 0
    for _, role in pairs(room.players) do
        table.insert(room_data.names, role.name)
    end

    for _, role in pairs(room.mid_players) do
        table.insert(room_data.names, role.name)
    end

    player:send(msg.MID_ENTER, room_data, ask_data)
end

MSG_REG[msg.ENTER] = function(player, room_id, is_mid_enter, is_visit)
    if player.room then
        LERR("enter room failed, already in room: %d, pid: %d", player.room.id, player.id)
        player:send(msg.ENTER, 1)
        return
    end

    local room = room_tbl[room_id]
    if not room then
        LLOG("enter room failed, invalid room_id: %d, pid: %d", room_id, player.id)
        player:send(msg.ENTER, 2)
        return
    end

    if not game.CAN_VISIT then
        is_visit = nil
    end

    if not game.CAN_MID_ENTER then
        is_mid_enter = nil
    end

    local is_ask, ask_data, is_full = should_ask(room)
    local idx
    if is_mid_enter then
        if ask_data == nil or not ask_data.can_mid_enter then
            player:send(msg.ENTER, 4)
            return
        end

        for i = 1, room.player_size do
            if room.players[i] == nil and room.mid_players[i] == nil then
                idx = i
                room.mid_players[i] = player
                break
            end
        end

        player.info = game.create_info(nil, room)
        player.info.is_mid_enter = true
    elseif is_visit then
        if ask_data == nil or not ask_data.can_visitor then
            player:send(msg.ENTER, 4)
            return
        end
        idx = 1
        add_visit_role(player, room)
    elseif is_ask then
        send_ask(room, player, ask_data)
        return
    else
        if is_full then
            player:send(msg.ENTER, 4)
            return
        end

        if room.gaming then
            LERR("enter room failed, is gaming, room_id: %d, pid: %d", room.id, player.id)
            player:send(msg.ENTER, 6)
            return
        end

        for i = 1, room.player_size do
            if room.players[i] == nil then
                idx = i
                room.players[i] = player
                break
            end
        end

        player.info = game.create_info(nil, room)
    end

    player.room = room
    player.game_id = game_id

    player:send(msg.ENTER, room:get_data())

    for i, role in pairs(room.players) do
        if role ~= player then
            role:send(init_msg(player, idx - i, idx))
        end
        player:send(init_msg(role, i - idx, i, is_visit))
    end

    for i, role in pairs(room.mid_players) do
        if role ~= player then
            role:send(init_msg(player, idx - i, idx))
        end
        player:send(init_msg(role, i - idx, i, is_visit))
    end
    LLOG("enter room success, room_id: %d, pid: %d", room_id, player.id)
end

MSG_REG[msg.RENTER] = function(player)
    local room = player.room
    if not room then
        LERR("re enter room failed, not in room, pid: %d", player.id)
        player:send(msg.RENTER)
        return
    end

    local idx
    if player.info.is_mid_enter then
        idx = table.index(room.mid_players, player)
    else
        idx = table.index(room.players, player)
    end

    local is_visit = get_visit_info(player)
    if is_visit then
        idx = 1
    end

    for i, role in pairs(room.players) do
        player:send(init_msg(role, i - idx, i, role == room.zhuang, is_visit))
    end

    for i, role in pairs(room.mid_players) do
        player:send(init_msg(role, i - idx, i, role == room.zhuang, is_visit))
    end

    if not is_visit then
        room:broadcast_all(msg.OFFLINE, player.id, "")
        if room.dismiss_time ~= nil then
            player:send(msg.APPLY, room.dismiss_tbl, room.dismiss_time - os.time())
        end
        game.renter(room, player)
    end
    LLOG("re enter room success, room_id: %d, pid: %d", room.id, player.id)
end

local function get_other_player(room)
    local dismiss_tbl = room.dismiss_tbl
    local tbl = {}
    for _, role in pairs(room.players) do
        if not table.index(dismiss_tbl, role.id) then
            table.insert(tbl, role)
        end
    end

    return tbl
end

local function add_timer(room)
    local stoped = false
    timer.add_timeout(200, function()
        if stoped then
            return
        end

        local players = get_other_player(room)
        for _, role in pairs(players) do
            MSG_REG[msg.AGREE](role, true)
        end
    end)

    return function()
        stoped = true
    end
end

MSG_REG[msg.APPLY] = function(player)
    local room = player.room
    if not room then
        LERR("apply dismiss failed, not in room, pid: %d", player.id)
        return
    end

    if room.dismiss_time ~= nil then
        LERR("room: %d dismiss is already", room.id)
        return
    end

    if table.length(room.players) == 1 then
    	MSG_REG[msg.AGREE](player, true)
    	return
    end

    table.insert(room.dismiss_tbl, player.id)

    room.dismiss_time = os.time() + 200
    if room.stop_timer then
        room.stop_timer()
    end
    room.stop_timer = add_timer(player.room)

    room:broadcast(msg.APPLY, room.dismiss_tbl, room.dismiss_time - os.time())
end

MSG_REG[msg.DISMISS] = function(player)
    local room = player.room
    if not room then
        LERR("room is not exist by player: %d", player.id)
        return
    end

    if room.start_count > 0 then
        LERR("room:%d game is ready", room.id)
        return
    end

    if room.host ~= player then
        LERR("is not room host by player: %d", player.id)
        return
    end

    room:broadcast(msg.DISMISS)
    room:delete()
end

MSG_REG[msg.ROOM_OUT] = function(player)
    local room = player.room
    if not room then
        LERR("room is not exist by player: %d", player.id)
        return
    end

    if del_visit_role(player) then
        return
    end

    if room.start_count > 0 then
        LERR("room:%d game is ready", room.id)
        return
    end

    if room.host == player then
        LERR("is room host by player: %d", player.id)
        return
    end

    if player.info.is_ready then
        MSG_REG[msg.READY](player, false)
    end

    room:broadcast(msg.ROOM_OUT, player.id)

    for idx, role in pairs(room.players) do
        if role == player then
            room.players[idx] = nil
            break
        end
    end
    player.room = nil
end

local function clear_dismiss(room)
    room.dismiss_time = nil
    room.dismiss_tbl = {}
    if room.stop_timer then
        room.stop_timer()
        room.stop_timer = nil
    end
end

local DISMISS_NEED = {1, 2, 2, 3, 4, 5}
MSG_REG[msg.AGREE] = function(player, is_agree)
    local room = player.room
    if not room then
        LERR("invalid not in room, pid: %d", player.id)
        return
    end

    local dismiss_tbl = room.dismiss_tbl
    local dismiss_count = #dismiss_tbl
    if dismiss_count == 0 and table.length(room.players) ~= 1 then
        LERR("not apply, room_id: %d, pid: %d", room.id, player.id)
        return
    end

    if not is_agree then
        LLOG("disagree dismiss room: %d by player: %d", room.id, player.id)
        clear_dismiss(room)
        room:broadcast(msg.AGREE, false, player.id)
        return
    end

    if table.index(dismiss_tbl, player.id) then
        LERR("already agree dismiss room: %d, by player: %d", room.id, player.id)
        return
    end

    table.insert(dismiss_tbl, player.id)
    dismiss_count = dismiss_count + 1

    local is_dismiss = false
    if dismiss_count >= DISMISS_NEED[table.length(room.players)] then
        is_dismiss = true
    end

    if not is_dismiss then
        LERR("The room: %d is not enough to dismiss count: %d", room.id, dismiss_count)
        room:broadcast(msg.AGREE, true, player.id)
        return
    end

    clear_dismiss(room)
    room:broadcast(msg.AGREE, true, player.id, true)
    room.is_dismiss = true
    room:end_game()
end

MSG_REG[msg.GET_ROOM] = function(player)
    local room = player.room
    if not room then
        LERR("invalid not in room, pid: %d", player.id)
        return
    end

    player:send(msg.GET_ROOM, room:get_data())
end

return function(_game_name, _game_path)
    game_name = _game_name
    game = require("game_require")(game_name, _game_path)
end
