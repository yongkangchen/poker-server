local visit = {}

function visit.broadcast_visit(room, skip_msg, ...)
    local args = {...}
    if args[1] == skip_msg then
        return
    end
    for _, role in pairs(room.visit_players or {}) do
        role:send(...)
    end
end

function visit.get_visit_info(player)
    if player.info then
        return player.info.is_visit
    end
end

function visit.clean_visit_role(room, is_dismiss)
    for _, role in pairs(room.visit_players or {}) do
        if is_dismiss then
            role:send(is_dismiss)
        end
        role.room = nil
        role.info.visit = nil
    end
    room.visit_players = nil
end

function visit.add_visit_role(player, room)
    for i = 1, room.player_size * 4 do
        if room.visit_players[i] == nil then
            room.visit_players[i] = player
            break
        end
    end
    player.info = {}
    player.info.visit = true
    player.room = room
end    
    
function visit.del_visit_role(player)
    local room = player.room
    for idx, role in pairs(room.visit_players or {}) do
        if role == player then
            room.visit_players[idx] = nil
            break
        end
    end
    player.room = nil
    player.info.visit = nil
end

return visit