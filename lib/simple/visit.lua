local visit = {
    MAX_NUM = 20,
}

function visit.broadcast(room, ...)
    for _, role in pairs(room.visit_players) do
        role:send(...)
    end
end

function visit.is_full(room)
    return table.length(room.visit_players) >= visit.MAX_NUM
end

function visit.check(player)
    return table.index(player.room.visit_players, player)
end

function visit.clean(room, is_dismiss)
    for _, role in pairs(room.visit_players) do
        if is_dismiss then
            role:send(is_dismiss)
        end
        role.room = nil
        role.visit_size = nil
    end
    room.visit_players = {}
end

function visit.add_role(player, room)
    local i = 1
    while true do
        if room.visit_players[i] == nil then
            room.visit_players[i] = player
            break
        end
        i = i + 1
    end
    player.room = room  --一个room_id 的字段也可以
    player.visit_size = #room.players
end

function visit.del_role(player, is_room_out)
    local room = player.room
    local idx = visit.check(player)
    if not idx then
        return
    end
    if is_room_out then
        player.visit_size = nil
    end
    
    room.visit_players[idx] = nil
    player.room = nil
    return true
end

return visit
