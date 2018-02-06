local msg = require "msg"
local visit = {
    MAX_NUM = 20,
}

function visit.broadcast(room, ...)
    for role in pairs(room.visit_players) do
        role:send(...)
    end
end

function visit.is_full(room)
    return table.length(room.visit_players) >= visit.MAX_NUM
end

function visit.check(player)
    if player.room.visit_players[player] then
        return true
    end
end

function visit.clean(room)
    for role in pairs(room.visit_players) do
        table.insert(room.players, role)
    end
    room.visit_players = {}
end

function visit.add_role(player, room)
    room.visit_players[player] = {
        player_idx = table.length(room.players) + table.length(room.mid_enter) + 1 --假设自己是进入房间的第x个人
    }
    player.room = room
end

function visit.player_idx(player)
    if visit.check(player) then
        return player.room.visit_players[player].player_idx
    end
end

function visit.get_player(player)
    local room = player.room
    local visit_player = {}
    for role in pairs(room.visit_players) do
        visit_player[role.id] = role.name
    end
    return visit_player
end

function visit.del_role(player, is_sit)
    local room = player.room
    if not visit.check(player) then
        return
    end
    room.visit_players[player] = nil
    player.room = nil
    room:broadcast_all(msg.VISITOR_LIST, player.id, is_sit)
    return true
end

return visit
