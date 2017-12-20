--[[
https://github.com/yongkangchen/poker-server

Copyright (C) 2016  Yongkang Chen lx1988cyk#gmail.com

GNU GENERAL PUBLIC LICENSE
   	Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.
--]]
local so_folder = jit.os
if jit.os == "Windows" then
    so_folder = so_folder .. jit.arch
end
package.cpath = package.cpath .. ";./libc/" .. so_folder .."/?.so"
package.path = package.path .. ";./lib/?.lua;./lib/net/?.lua;./src/?.lua;./lib/lobby/?.lua;./lib/lobby/lib/?.lua;./lib/simple/?.lua"

math.randomseed(os.time())

require "ext"

local log = require "log"
local LLOG = log.log
local LERR = log.error
local LTRACE = log.trace
local debug_traceback = debug.traceback

local function msg_send(client, ... )
    if client.fd == nil then
        return
    end
    client:write(table.dump{...} .. "\r\n")
end

MSG_REG = MSG_REG or { }

local function msg_handle(agent, pt, ...)
    local func = MSG_REG[ pt ]
    if func == nil then
        LERR("unknow pack, type: 0x%08x, sid: 0x%08x", pt, agent.sid or 0)
        return
    end
    LTRACE("recv msg, pid: %d, type: 0x%08x, %s", agent.id or 0, pt, table.dump{...})
    
    if pt > 0x0010 and agent.id == nil then
        LERR("invalid pack, type: 0x%08x, sid: 0x%08x", pt, agent.sid or 0)
        return
    end
    func(agent, ...)
end

require "login"

return function(port)
    LLOG("listen: 0.0.0.0: %d", port)
    require "tcp_svr".start("0.0.0.0", port, function(client)
    	coroutine.wrap(function()
            LLOG("accept, fd: %s, ip: %s, port: %s", client.fd, client.ip, client.port)
            
            client.send = msg_send
            client.agent = client
            
    		while true do
                local msg = table.undump(client:read_line())
    			local size = table.maxn(msg)
    			if size < 256 then
    				local ok, err = xpcall(msg_handle, debug_traceback, client.agent, unpack(msg, 1, size))
    				if not ok then
    					LERR("handler error: %s", debug_traceback(err))
    				end	
    			else
    				LERR("invalid size: " .. size)
    			end
    		end
    	end)()
    end)
end
