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
    if table.index(player.room.visit_players, player) then
        return player.room.players[1].id
    end
end

function visit.clean(room, is_dismiss)
    for _, role in pairs(room.visit_players) do
        if is_dismiss then
            role:send(is_dismiss)
        end
        role.room = nil
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
end

function visit.del_role(player)
    local room = player.room
    local idx = table.index(player.room.visit_players, player)
    if not idx then
        return
    end
    room.visit_players[idx] = nil
    player.room = nil
    return true
end

return visit
