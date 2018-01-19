local visit = {
    MAX_NUM = 20,
}

function visit.broadcast_visit(room, ...)
    for _, role in pairs(room.visit_players) do
        role:send(...)
    end
end

function visit.is_full(room)
    return table.length(room.visit_players) >= visit.MAX_NUM
end

function visit.get_visit_info(player)
    return table.index(player.room.visit_players, player)
end

function visit.clean_visit_role(room, is_dismiss)
    for _, role in pairs(room.visit_players) do
        if is_dismiss then
            role:send(is_dismiss)
        end
        role.room = nil
    end
    room.visit_players = {}
end

function visit.add_visit_role(player, room)
    for i = 1, room.player_size * 4 do
        if room.visit_players[i] == nil then
            room.visit_players[i] = player
            break
        end
    end
end

function visit.del_visit_role(player)
    local room = player.room
    local idx = visit.get_visit_info(player)
    if not idx then
        return
    end
    room.visit_players[idx] = nil
    player.room = nil
    return true
end

return visit
