-- webserver by PixelToast

socket=require("socket")
lfs=require("lfs")
version="0.1"

dofile("lua/util.lua")
dofile("lua/fs.lua")

-- read config

configfile=configfile or "config.txt"
local dconfig=config
function loadconfig()
	local file=assert(io.open(configfile))
	config={}
	setfenv(assert(loadstring(file:read("*a"))),config)()
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
	if dconfig then
		merge(dconfig,config)
	end
	print("loaded "..configfile)
end
loadconfig()

-- load apis

dofile("lua/hook.lua")
dofile("lua/client.lua")
dofile("lua/receivehead.lua")
dofile("lua/runlua.lua")
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
			print("got client "..sk:getfd().." "..(sk:getpeername() or "*"))
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


