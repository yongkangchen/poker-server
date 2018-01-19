# poker-server

1、安装luajit
https://luapower.com/luajit/download

2、启动服务器
`luajit lib/main.lua 9878 zzmj`


http://linkcloud.github.io/


# 开发注意

game返回的额外字段说明：

NO_COST_ALL：房主开房模式的局数对应的钻石消耗

COST_ALL：AA开房模式的局数对应的钻石消耗

# 沙箱限制
禁止设置全局变量

禁止修改全局变量

禁止使用以下函数：
```
print
collectgarbage 
dofile 
getfenv 
getmetatable 
load 
loadfile 
loadstring 
rawequal 
rawget 
rawset 
setfenv 
setmetatable 
module 
newproxy 
gcinfo 
```

禁止使用：
```
jit.
package.
_G.
debug.
```

禁止require访问:
```
lib/net/poll.lua
lib/net/tcp_svr.lua
lib/simple/login.lua
lib/simple/room.lua
lib/check_game.lua
lib/ext.lua
lib/game_require.lua
lib/main.lua
lib/sanbox.lua
lib/start.lua
libc/*
```

开放的参考sandbox.lua:
```
_VERSION assert error        ipairs     next pairs
pcall        select tonumber tostring type unpack xpcall
coroutine.create coroutine.resume coroutine.running coroutine.status
coroutine.wrap     coroutine.yield
math.abs     math.acos math.asin    math.atan math.atan2 math.ceil math.mod
math.cos     math.cosh math.deg     math.exp    math.fmod    math.floor
math.frexp math.huge math.ldexp math.log    math.log10 math.max
math.min     math.modf math.pi        math.pow    math.rad     math.random
math.sin     math.sinh math.sqrt    math.tan    math.tanh
os.clock os.difftime os.time os.date
string.byte string.char    string.find    string.format string.gmatch
string.gsub string.len     string.lower string.match    string.reverse
string.sub    string.upper string.gfind
table.insert table.maxn table.remove table.sort
table.foreach table.foreachi table.getn table.concat
bit

require "log"
require "timer"
require "msg"

table.is_empty
table.copy
table.index
table.length
table.update
table.random
table.is_same_day
table.merge
table.dump
string.split

require
MSG_REG

```
