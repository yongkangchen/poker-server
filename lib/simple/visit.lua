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
    if player == nil then
        return
    end
    return player.room.visit_players[player]
end

function visit.clean(room, is_dismiss)
    for role, _ in pairs(room.visit_players) do
        if is_dismiss then
            role:send(is_dismiss)
        end
        role.room = nil
    end
    room.visit_players = {}
end

function visit.add_role(player, room)
    if room.visit_players[player] == nil then
        room.visit_players[player] = {
            player_size = table.length(room.players) + table.length(room.mid_enter) + 1 --假设自己是进入房间的第x个人
        }
    end
    player.room = room
end

function visit.player_size(player)
    local size = visit.check(player)
    if size then
        return size.player_size
    end
end

function visit.get_player(player)
    local room = player.room
    local count = 0
    local visit_player = {}
    for role in pairs(room.visit_players) do
        if role ~= player then
            count = count + 1
            visit_player[role.id] = role.name
        end
    end
    return visit_player, count
end

function visit.del_role(player, is_room_out)
    local room = player.room
    if not visit.check(player) then
        return
    end
    room.visit_players[player] = nil
    player.room = nil
    
    return true
end

return visit
