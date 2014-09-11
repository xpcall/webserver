-- webserver by PixelToast
-- TODO:
--  increase efficiency by using ffi char[] instead of strings
--  more speed debugging

socket=require("socket")
lfs=require("lfs")
version="0.1"

-- read config

local file=assert(io.open("config.txt"))
config={}
setfenv(assert(loadstring(file:read("*a"))),config)()

-- domain config defaults

assert(config.domains)
assert(config.domains.default)
setmetatable(config.domains,{
	__index=function(s,n)
		return config.domains.default
	end
})
for k,v in pairs(config.domains) do
	if k~="default" then
		setmetatable(v,{
			__index=config.domains.default,
		})
	end
end

-- load apis

dofile("lua/util.lua")
dofile("lua/fs.lua")
dofile("lua/hook.lua")
dofile("lua/client.lua")
dofile("lua/receivehead.lua")
dofile("lua/serve.lua")

-- start server

local sv=assert(socket.bind(config.bindTo or "*",config.port))
sv:settimeout(0) -- non-blocking
hook.newsocket(sv)
print("listening on port "..config.port)

hook.new("select",function(rq,sq)
	if rq[sv] then
		local sk=assert(sv:accept())
		while sk do
			print("got client "..sk:getfd())
			hook.newsocket(sk)
			sk:settimeout(0)
			client.new(sk)
			sk=sv:accept()
		end
	end
end,"server socket manager")

-- main blocking loop

while true do
	local rq,sq=socket.select(hook.sel,hook.rsel,math.min(5,hook.interval or 5))
	hook.queue("select",rq,sq)
end


