--[[
https://github.com/yongkangchen/toynet

The MIT License (MIT)

Copyright (c) 2016 Yongkang Chen <lx1988cyk at gmail dot com>

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
local math_random = math.random

function table.is_empty( tbl )
    return ( tbl == nil ) or ( _G.next( tbl ) == nil )
end

function table.undump( str  )
    if not str then
        return
    end

    local fun = loadstring( "return ".. str  )
    if fun then
        return fun()
    end
end

function table.copy( src )
    local dst = {}
    for k,v in pairs(src) do
        dst[k] = v
    end
    return dst
end

function table.index(tbl, obj)
    if tbl == nil or obj == nil then
        return
    end
    for i,v in pairs(tbl) do
        if v == obj then
            return i
        end
    end
end

function table.length(tbl)
    if tbl == nil then
        return 0
    end
    
    local n = 0
    for _ in pairs(tbl) do
        n = n + 1
    end
    return n
end

function table.update(old, new)
    for k in pairs(old) do
        old[k] = nil
    end
    for k,v in pairs(new) do
        old[k] = v
    end
end

function table.random(tbl)
    local rand_tbl = {}
    for _ = 1, #tbl do
        local idx = math_random(#tbl)
        table.insert(rand_tbl, tbl[idx])
        table.remove(tbl, idx)
    end
    for i = 1, #rand_tbl do
        tbl[i] = rand_tbl[i]
    end
    return tbl
end

function table.is_same_day( date_a, date_b )
    return date_a.yday == date_b.yday
        and date_a.year == date_b.year
end

local string = string
function string:split(_sep)
    local sep, fields = _sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

function table.merge(dst, src)
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end

