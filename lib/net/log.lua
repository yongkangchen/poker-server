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

local table = table
function table.dump( object )
    if type(object) == 'table' then
        local s = '{ '
        for k,v in pairs(object) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. table.dump(v) .. ','
        end
        return s .. '} '
    elseif type(object) == 'function' then
        return "@@@function"
    elseif type(object) == 'string' then
        return string.format("%q", object)
    else
        return tostring(object)
    end
end

local string_format = string.format
local table_dump = table.dump
local debug_traceback = debug.traceback

local clog = function(type, file, line, funname, str)
    print(string_format("%s[%s:%s:%s:LEV_%d] %s", os.date("[%m/%d %H:%M:%S]"), file, line, funname, type, str))
end

local function __FILE__() return debug.getinfo(4,'S').source  end
local function __LINE__() return debug.getinfo(4, 'l').currentline end
local function __FUNC__() return debug.getinfo(4, 'n').name or "*" end

local function llog( type, str)
    clog( type, __FILE__(), __LINE__(), __FUNC__(), str)
end

local function LSAFE_FORMAT( ... )
    local success,result = pcall(string_format, ...)
    if not success then
        local msg = table_dump{...}
        return 'LOG_ERROR: ' .. result .. msg .. "\n" ..debug_traceback()
    end
    return result
end

local LLOG_TRACE = 2
local LLOG_LOG   = 4
local LLOG_ERR   = 8

local log = {}
function log.trace( ... )
	llog(LLOG_TRACE, LSAFE_FORMAT(...))
end

function log.log( ... )
	llog(LLOG_LOG, LSAFE_FORMAT(...))
end

function log.error( ... )
	llog(LLOG_ERR, LSAFE_FORMAT(...))
end
return log