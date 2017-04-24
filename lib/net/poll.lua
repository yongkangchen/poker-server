--[[
https://github.com/yongkangchen/toynet

The MIT License (MIT)

Copyright (c) 2016 Yongkang Chen lx1988cyk#gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

local fd_poll = require "fd_poll"
local fd_poll_create = fd_poll.create
local fd_poll_add = fd_poll.add
local fd_poll_mod = fd_poll.mod
local fd_poll_wait = fd_poll.wait
local fd_poll_del = fd_poll.del

local coroutine_resume = coroutine.resume
local LERR = require "log".error
local tcp_nonblock = require "tcp".nonblock

local function watch(poll_fd, fd, write_cb)
    local read_co
    local read_enable = true
    local write_enable = false
    local function update_enable()
        if fd and fd_poll_mod(poll_fd, fd, read_enable, write_enable) == -1 then
            LERR("error mod fd: %d", fd)
        end
    end
    
    local function dispatch(readable, writeable)
        if readable then
            if read_co then
                coroutine_resume(read_co)
            else
                read_enable = false
                update_enable()
            end
        end

        if writeable and write_cb then
            write_cb()
        end
    end
    
    return dispatch, {
        wait = function()
            if read_enable == false then
                read_enable = true
                update_enable()
            end

            assert(read_co == nil)
            read_co = coroutine.running()
            coroutine.yield()
            read_co = nil
        end,
        write_enable = function(v)
            if write_enable == v then
                return
            end
            write_enable = v
            update_enable()
        end,
    }
end

return function()
    local poll_fd = fd_poll_create()
    assert(poll_fd >= 0, "fd_poll create failed")
    
    local event_list = {}
    local function dispatch_event(fd, read_enable, write_enable)
        local func = event_list[fd]
        if func == nil then
            LERR("error dispatch: %d", fd)
            return
        end
        func(read_enable, write_enable)
    end
    
    return {
        watch = function(fd, write_cb)
            if fd_poll_add(poll_fd, fd) == -1 then
                LERR("error add fd to poll: %d", fd)
                return
            end
            
            if tcp_nonblock(fd, true) == -1 then
                LERR("error tcp_nonblock: %d", fd)
            end

            local dispatch, event = watch(poll_fd, fd, write_cb)
            event_list[fd] = dispatch
            return event
        end,
        wait = function(timeout)
            fd_poll_wait(poll_fd, timeout or -1, dispatch_event)
        end,
        del = function(fd)
            event_list[fd] = nil
            fd_poll_del(poll_fd, fd)
        end
    }
end