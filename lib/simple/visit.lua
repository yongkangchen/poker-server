local msg = require "msg"
local visit = {
    MAX_NUM = 20,
}

function visit.broadcast(room, ...)
    for role, _ in pairs(room.visit_players) do
        role:send(...)
    end
end

function visit.is_full(room)
    return table.length(room.visit_players) >= visit.MAX_NUM
end

function visit.check(player)
    if player.room and player.room.visit_players[player] then
        return true
    end
end

function visit.clean(room, is_dismiss)
    for role in pairs(room.visit_players) do
        if is_dismiss then
            role:send(is_dismiss)
        end
        role.room = nil
    end
    room.visit_players = {}
end

function visit.add_role(player, room)
    room.visit_players[player] = {
        player_size = table.length(room.players) + table.length(room.mid_enter) + 1 --假设自己是进入房间的第x个人
    }
    player.room = room
end

function visit.player_size(player)
    if visit.check(player) then
        return player.room.visit_players[player].player_size
    end
end

function visit.get_player(player)
    local room = player.room
    local visit_player = {}
    for role in pairs(room.visit_players) do
        table.insert(visit_player, {role.id, role.name, role.headimgurl})
    end
    return visit_player
end

function visit.del_role(player)
    local room = player.room
    if not visit.check(player) then
        return
    end
    room.visit_players[player] = nil
    player.room = nil
    room:broadcast_all(msg.VISITOR, player.id)
    return true
end

return visit
