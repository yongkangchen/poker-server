--[[
https://github.com/yongkangchen/poker-server

Copyright (C) 2016  Yongkang Chen lx1988cyk#gmail.com

GNU GENERAL PUBLIC LICENSE
   	Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.
--]]

local do_check_hu = require "hu"
local msg = require "msg"
local log = require "log"
local LERR = log.error
local LLOG = log.log

local HORSE_TBL = {
    [0] = true,
    [2] = true,
    [4] = true,
    [6] = true,
}

local function remove_card(tbl, value, count)
    count = count or 1
    for i = #tbl, 1, -1 do
        if tbl[i] == value then
            table.remove(tbl, i)
            count = count - 1
            if count == 0 then
                return
            end
        end
    end
end

local function get_next_idx(idx)
    idx = idx + 1
    return idx == 5 and 1 or idx
end

local band = bit.band
local rshift = bit.rshift

local function check_dict_hu(dict, seven_hu)
    local results = do_check_hu(dict)
    if results and #results == 1 and results[1] == 0x4000000 and not seven_hu then
        results = nil
    end
    return results
end

local function check_hu(room, cards, card)
    local dict = {}
    
    for _, v in ipairs(cards) do
        dict[v] = (dict[v] or 0) + 1
    end
    
    if card then
        dict[card] = (dict[card] or 0) + 1
    end
    
    local results = check_dict_hu(dict, room.seven_hu)
    if not results then
        return
    end
    
    if room.seven_hu and results[1] == 0x4000000 then
        return 2
    end
    
    if room.peng_hu then
        for _, result in ipairs(results) do
            local shunzi = band(rshift(result, 3), 0x7)
            if shunzi == 0 then
                return 2
            end
        end
    end
    return 1
end

local function card_count(tbl, value)
    local count = 0
    for _, v in ipairs(tbl) do
        if v == value then
            count = count + 1
        end
    end
    return count
end


local function create_info(result)
    return {
        result = result or {
            total_score = 0,
            win_count = 0, 
            gang_count = 0, 
            an_gang_count = 0, 
            fang_gang_count = 0,
            horse_count = 0, 
            pao_count = 0
        },
        score = 0,
        is_ready = false,
    }
end

local start_room
local function set_init_msg(player, data)
    local player_info = player.info
    data.extra = player_info.extra
    data.new_idx = player_info.new_idx
    data.can_out = player.room.can_out and player.room.players[player.room.idx] == player
    data.pre_out_role = player.room.pre_out_role == player
end

local function create_room(player, horse, peng_hu, seven_hu, can_pao, horse_type)
    if not HORSE_TBL[horse] then
        LERR("create_room failed, invalid horse: %d, pid: %d", horse, player.id)
        return
    end
    
    return {
        player_size = 4,
        idx = 1,
        zhuang = nil,
        
        horse = horse,
        horse_type = horse_type,
        peng_hu = peng_hu,
        seven_hu = seven_hu,
        can_pao = can_pao,
        create_data = {
            horse = horse,
            seven_hu = seven_hu,
            can_pao = can_pao,
            qianggang_hu = true,
        },
        start_idx = 1,
        can_out = false,
    }
end

local function renter(_, player)
    for name in pairs(player.info.select or {}) do
        player:send(msg.SELECT, name)
    end
end

local function add_gang_score(player, player_dict)
    for _, v in ipairs(player.info.extra or {}) do
        if v.num == 4 then
            if v.pid then
                local out_player = player_dict[v.pid]
                out_player.info.score = out_player.info.score - 3
                player.info.score = player.info.score + 3
            else
                local add_score = v.gong and 1 or 2
                for _, role in pairs(player_dict) do
                    if role == player then
                        role.info.score = role.info.score + add_score * 3
                    else
                        role.info.score = role.info.score - add_score
                    end
                end
            end
        end
    end
end

local function get_result(room, is_over)
    local horse_tbl = room.horse_tbl
    room.horse_tbl = nil
    
    local player_dict = {}
    for _, role in ipairs(room.players) do
        player_dict[role.id] = role
    end
    
    for _, role in ipairs(room.players) do
        add_gang_score(role, player_dict)
    end
    
    local result = {}
    for idx, role in ipairs(room.players) do
        role.info.result.total_score = role.info.result.total_score + role.info.score
        table.insert(result, {
            name = role.name,
            id = role.id,
            headimgurl = role.headimgurl,
            
            is_host = role == room.host,
            is_zhuang = idx == room.next_start_idx,
            extra = role.info.extra,
            
            hand = role.info.hand,
            add_score = role.info.score,
            
            is_pao = role.info.is_pao,
            zimo = role.info.zimo,
            hu_card = room.hu_card,
            horse_tbl = role.info.horse_tbl,
            result = is_over and role.info.result or nil,
        })
        role.info = create_info(role.info.result)
    end
    result.horse = horse_tbl
    room.hu_card = nil
    if not is_over then
        room.start_idx = room.next_start_idx or room.start_idx
    end
    return result
end

local function add_card(player, skip)
    local room = player.room
    local size = #room.cards
    if size == 0 then
        room.next_start_idx = table.index(room.players, player)
        room:end_game()
        return
    end
    
    local card = table.remove(room.cards)
    local card_idx
    for i, v in ipairs(player.info.hand) do
        if v > card then
            card_idx = i
            break
        end
    end
    card_idx = card_idx or #player.info.hand + 1
    table.insert(player.info.hand, card_idx, card)
    player.info.new_idx = card_idx
    
    if skip then
        LERR("init add_card: %d, pid: %d", card, player.id)
        return
    end
    
    local idx
    for i, role in ipairs(room.players) do
        if role == player then
            idx = i
            role:send(msg.ADD, player.id, card, card_idx)
        else
            role:send(msg.ADD, player.id)
        end
    end

    table.insert(room.playback, table.dump{msg.ADD, player.id, card, card_idx})
    room.can_out = true
    room.idx = idx
    
    LERR("add_card: %d, pid: %d", card, player.id)
end

start_room = function(room)
    local cards = {}
    for value = 0, 26 do
        for _ = 1, 4 do
            table.insert(cards, value)
        end
    end
    
    table.random(cards)
    room.cards = cards
    -- room.cards = table.copy(require "test.card")
    room.idx = room.start_idx
    room.hu_count = nil
    
    local zhuang_player = room.players[room.idx]
    room.zhuang = zhuang_player
    
    for _, player in ipairs(room.players) do
        local player_info = player.info
        player_info.hand = {}
        player_info.extra = {}
        player_info.out = {}
        player_info.select = {}
        player_info.disable_peng = {}
        player_info.guo_pinghu = false
        player_info.guo_dahu = false
        for _ = 1, 13 do
            add_card(player, true)
        end
        
        player_info.new_idx = nil
        
        if player == zhuang_player then
            add_card(player, true)
        end
        
        player:send(msg.START, player_info.hand, zhuang_player.id)
    end
    
    room.can_out = true
    room:broadcast(msg.START_OUT, zhuang_player.id)
    
    LERR("start_game, room_id: %d", room.id)
end

local function check_next(room, step, force_pao)
    local out_player = room.out_player
    local card = room.out_card
    
    if step == 1 and (room.can_pao or force_pao) then
        if room.create_data.qianggang_hu then 
            local pao_tbl = {}
            for _, player in ipairs(room.players) do
                if player ~= out_player and not player.info.guo_dahu then
                    local ret = check_hu(room, player.info.hand, card)
                    if ret then
                        if not player.info.guo_pinghu or ret > 1 then 
                            player.info.select.hu = true
                            player:send(msg.SELECT, "hu")
                            pao_tbl[player] = ret
                        end
                    end
                end
            end    
            if not table.is_empty(pao_tbl) then
                room.pao_tbl = pao_tbl
                return
            end
        end
    end

    if step <= 2 then
        for _, player in ipairs(room.players) do
            if player ~= out_player and card_count(player.info.hand, card) == 3 then
                player.info.select.gang = true
                player:send(msg.SELECT, "gang")
                
                if player.info.disable_peng[card] == nil then
                    player.info.select.peng = card
                    player:send(msg.SELECT, "peng")
                end
                return
            end
        end
        
        for _, player in ipairs(room.players) do
            if player ~= out_player and player.info.disable_peng[card] == nil 
                and card_count(player.info.hand, card) == 2 then
                    player.info.select.peng = card
                    player:send(msg.SELECT, "peng")
                    return
            end
        end
    end
    
    local next_idx = room.out_idx
    local next_player = room.players[next_idx]
    add_card(next_player)
end

local function ROOM_MSG_REG(pt, func)
    MSG_REG[pt] = function(player, ...)
        local room = player.room
        if not room then
            LERR("room msg failed, pt: 0x%08x, not in room, pid: %d", pt, player.id)
            return
        end
        
        func(room, player, ...)
    end
end

ROOM_MSG_REG(msg.ZZ_OUT, function(room, player, idx, card)
    if not room.can_out then
        LERR("failed out card, room can not out, room_id: %d, pid: %d", room.id, player.id)
        return
    end
    
    local out_player = room.players[room.idx]
    if out_player ~= player then
        LERR("failed out card, not in out turn, room_id: %d, pid: %d", room.id, player.id)
        return
    end
    
    if card == nil then
        LERR("invalid out card, pid: %d", player.id)
        return
    end
    
    if player.info.hand[idx] ~= card then
        LERR("failed out card, invalid card: %d, hand: %d, idx: %d, pid: %d", card, player.info.hand[idx], idx, player.id)
        return
    end
    
    table.remove(player.info.hand, idx)
    table.insert(player.info.out, card)
    room.can_out = false
    player.info.disable_peng = {}
    player.info.guo_pinghu = false
    player.info.guo_dahu = false
    player.info.new_idx = nil
    room:broadcast(msg.OUT, player.id, card)
    room.pre_out_role = player
    room.out_player = out_player
    room.out_card = card
    room.out_idx = get_next_idx(room.idx)
    check_next(room, 1)
    LLOG("out card success, room_id: %d, pid: %d, card: %d", room.id, player.id, card)
end)

ROOM_MSG_REG(msg.ZZ_HU, function(room, player, is_pao)
    local gang_score_count = 0
    for _, v in ipairs(player.info.extra) do
        if v.num == 4 then
            gang_score_count = gang_score_count + 1
        end
    end
    
    local hu_ret
    if is_pao == nil then
        if not room.can_out then
            LERR("hu failed, can not out, room_id: %d, pid: %d", room.id, player.id)
            return
        end
        
        if room.players[room.idx] ~= player then
            LERR("hu failed, not in turn, room_id: %d, pid: %d", room.id, player.id)
            return
        end
        
        if player.info.new_idx == nil then
            LERR("hu failed, nil new idx, room_id: %d, pid: %d", room.id, player.id)
            return
        end
        
        hu_ret = check_hu(room, player.info.hand)
        if not hu_ret then
            LERR("hu failed, can not hu, room_id: %d, pid: %d", room.id, player.id)
            return
        end
        
        room.can_out = false
        room.hu_card = player.info.hand[player.info.new_idx]
        player.info.zimo = true
        room.next_start_idx = room.idx
    else
        local pao_tbl = room.pao_tbl or {}
        hu_ret = pao_tbl[player]
        if not hu_ret then
            LERR("hu failed, zero hu_count, room_id: %d, pid: %d", room.id, player.id)
            return
        end
        
        pao_tbl[player] = nil
        player.info.select = {}
        
        local out_player = room.out_player
        
        if not is_pao then        
            if table.is_empty(pao_tbl) then
                if out_player.info.is_pao then
                    for _, role in ipairs(room.players) do
                        if role.info.is_pao == false then
                            room.next_start_idx = table.index(room.players, (room.hu_count == 1 and role) or room.out_player)
                            break
                        end
                    end
                    room:end_game()
                else    
                    if hu_ret >= 2 then
                        player.info.guo_dahu = true    
                    else
                        player.info.guo_pinghu = true    
                    end
                    check_next(room, 2) 
                end
            end
            LLOG("hu success, not is pao, room_id: %d, pid: %d", room.id, player.id)
            return
        end
        
        for i, v in ipairs(out_player.info.extra) do
            if v.value == room.out_card then
                table.remove(out_player.info.extra, i)
                break
            end
        end
        
        out_player.info.is_pao = true
        player.info.is_pao = false
        room.next_start_idx = table.index(room.players, player)
        room.hu_card = room.out_card
    end
    
    local horse
    if room.horse_type ~= 3 then
        horse = 0
    else
        horse = 1
    end
    
    local horse_tbl = {}
    local size = #room.cards
    
    local horse_size = room.horse
    
    for i = math.max(1, size - horse_size + 1), size do
        local card = room.cards[i]
        table.insert(horse_tbl, card)
        local card_num = card % 9 + 1
        if card_num == 1 or card_num == 5 or card_num == 9 then
            if room.horse_type ~= 3 then
                horse = horse + 1
            else
                horse = horse * 2
            end
            if not player.info.horse_tbl then
                player.info.horse_tbl = {}
            end 
            table.insert(player.info.horse_tbl, card)
        end
    end
    
    room.horse_tbl = horse_tbl

    local add_score = (is_pao == nil and 2 or 1) * hu_ret
    if room.horse_type ~= 3 then
        add_score = add_score + horse
    else
        add_score = add_score * horse
    end
    
    if is_pao == nil then    
        for _, role in ipairs(room.players) do
            role.info.score = role.info.score - add_score - gang_score_count
            player.info.score = player.info.score + add_score + gang_score_count
        end
    else
        local out_player = room.out_player
        
        out_player.info.score = out_player.info.score - add_score - gang_score_count
        out_player.info.result.pao_count = out_player.info.result.pao_count + 1
        
        player.info.score = player.info.score + add_score + gang_score_count
    end
    
    player.info.result.win_count = player.info.result.win_count + 1
    player.info.result.horse_count = player.info.result.horse_count + (horse == 0 and 0 or 1)
    room.hu_count = (room.hu_count or 0) + 1
    if not table.is_empty(room.pao_tbl) then
        LLOG("HU success, wait pao, room_id: %d, pid: %d", room.id, player.id)
        return
    end
    LLOG("HU success, room_id: %d, pid: %d", room.id, player.id)
    room.next_start_idx = table.index(room.players, (room.hu_count == 1 and player) or room.out_player)
    room:end_game()
end)

ROOM_MSG_REG(msg.ZZ_PENG, function(room, player, is_peng)
    local peng_card = player.info.select.peng
    if not peng_card then
        LERR("peng failed, not in select, pid: %d", player.id)
        return
    end
    
    player.info.select = {}
    
    if not is_peng then
        player.info.disable_peng[peng_card] = true
        check_next(room, 3)
        LLOG("peng success, not peng, room_id: %d, pid: %d", room.id, player.id)
        return
    end
    
    local out_player = room.players[room.idx]
    local card = table.remove(out_player.info.out)
    
    remove_card(player.info.hand, card, 2)
    table.insert(player.info.extra, {value = card, num = 3})
    
    room.can_out = true
    room.idx = table.index(room.players, player)
    room:broadcast(msg.PENG, player.id, out_player.id)
    room.pre_out_role = nil
    LLOG("peng success, room_id: %d, pid: %d", room.id, player.id)
end)

ROOM_MSG_REG(msg.ZZ_GANG, function(room, player, is_gang)
    if not player.info.select.gang then
        LERR("gang failed, not in select, pid: %d", player.id)
        return
    end
    player.info.select = {}
    
    if not is_gang then
        check_next(room, 3)
        LLOG("gang success, not gang, room_id: %d, pid: %d", room.id, player.id)
        return
    end
    
    local out_player = room.players[room.idx]
    local card = table.remove(out_player.info.out)
    remove_card(player.info.hand, card, 3)
    table.insert(player.info.extra, {value = card, num = 4, gong = true, pid = out_player.id})
    player.info.result.gang_count = player.info.result.gang_count + 1
    
    room:broadcast(msg.GANG, player.id, out_player.id)
    
    add_card(player)
    LLOG("gang success, room_id: %d, pid: %d", room.id, player.id)
end)

ROOM_MSG_REG(msg.ZZ_OUT_GANG, function(room, player, card)
    if not room.can_out then
        LERR("out gang failed, can not out, room_id: %d, pid: %d", room.id, player.id)
        return
    end
    
    if room.players[room.idx] ~= player then
        LERR("out gang failed, not in turn, room_id: %d, pid: %d", room.id, player.id)
        return
    end
    
    if card_count(player.info.hand, card) ~= 4 then
        LERR("out gang failed, lack card in hand, room_id: %d, pid: %d", room.id, player.id)
        return
    end
    remove_card(player.info.hand, card, 4)
    table.insert(player.info.extra, {value = card, num = 4})
    player.info.result.an_gang_count = player.info.result.an_gang_count + 1
    
    room:broadcast(msg.OUT_GANG, player.id, card)
    
    add_card(player)
    LERR("out gang success, room_id: %d, pid: %d", room.id, player.id)
end)

ROOM_MSG_REG(msg.ZZ_PENG_GANG, function(room, player, card)
    if not room.can_out then
        LERR("peng gang failed, can not out, room_id: %d, pid: %d", room.id, player.id)
        return
    end
    
    if room.players[room.idx] ~= player then
        LERR("peng gang failed, not in turn, room_id: %d, pid: %d", room.id, player.id)
        return
    end
    
    if card_count(player.info.hand, card) ~= 1 then
        LERR("peng gang failed, lack one card in hand, room_id: %d, pid: %d", room.id, player.id)
        return
    end
    
    local is_find = false
    for _, data in ipairs(player.info.extra) do
        if data.value == card and data.num == 3 then
            data.num = 4
            data.gong = true
            is_find = true
            break
        end
    end
    
    if not is_find then
        LERR("peng gang failed, lack card in extra, room_id: %d, pid: %d", room.id, player.id)
        return
    end
    
    remove_card(player.info.hand, card, 1)
    player.info.result.gang_count = player.info.result.gang_count + 1
    
    room:broadcast(msg.PENG_GANG, player.id, card)
    
    room.out_player = player
    room.out_card = card
    room.out_idx = room.idx
    room.can_out = false
    room.pre_out_role = nil
    
    check_next(room, 1, true)
    LERR("peng gang success, room_id: %d, pid: %d", room.id, player.id)
end)

return {
    BASE_ROUND = 8,
    create_room = create_room,
    create_info = create_info,
    renter = renter,
    get_result = get_result,
    start_room = start_room,
    
    set_init_msg = set_init_msg,
}
