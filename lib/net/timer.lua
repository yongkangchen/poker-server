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

local table_insert = table.insert
local math_min = math.min
local debug_traceback = debug.traceback
local LERR = require "log".error

local timer = {}
local time_wheel = {}
function timer.add_timeout(sec, func)
	local time = os.time() + sec
	local pool = time_wheel[time]
	if not pool then
		pool = {}
		time_wheel[time] = pool
	end
	table_insert(pool, coroutine.wrap(func))
end

local function compare_time(a, b)
	return a.time < b.time
end

function timer.update()
	local now = os.time()
	local wait = -1
	local execute_tbl = {}
	for time, tbl in pairs(time_wheel) do
		local diff = (time - now) * 1000
		if diff > 0 then
			if wait == -1 then
				wait = diff
			else
				wait = math_min(wait, diff)
			end
		else
			time_wheel[time] = nil
			tbl.time = time
			table.insert(execute_tbl, tbl)
		end
	end
	
	if #execute_tbl ~= 0 then
		table.sort(execute_tbl, compare_time)
		
		for _, tbl in ipairs(execute_tbl) do
			tbl.time = nil
			for _, func in ipairs(tbl) do
				local ok, ret = xpcall(func, debug_traceback)
				if not ok then
					LERR("handler error: %s", debug_traceback(ret))
				end
			end
		end
		return timer.update(0)
	end
	return wait
end
return timer