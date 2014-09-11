-- manages client sockets
-- buffers sending and receiving

clients={}
client={}
local buffering={}
function client.new(sk)
	local cl
	cl={
		sk=sk,
		sbuffer="",
		send=function(txt)
			if txt then
				cl.sbuffer=cl.sbuffer..txt
			end
			local t,err,c=sk:send(cl.sbuffer)
			if not t and err~="timeout" then
				cl.onError("send",err)
				return
			elseif not c then
				hook.remrsocket(cl.sk)
				bfrind=1
				cl.sbuffer=""
				buffering[cl.sk]=nil
				if cl.onDoneSending then
					local f=cl.onDoneSending
					cl.onDoneSending=nil
					f(cl)
				end
				return
			elseif not buffering[cl.sk] then
				hook.newrsocket(cl.sk)
				buffering[cl.sk]=cl
			end
			cl.sbuffer=cl.sbuffer:sub(c+1)
		end,
		close=function(...)
			-- cleanup
			hook.remsocket(sk)
			hook.remrsocket(sk)
			clients[sk]=nil
			buffering[cl]=nil
			sk:close()
			if cl.onClose then
				cl.onClose(...)
			end
		end,
		onError=function(t,err)
			cl.close()
		end,
		rbuffer="",
		receive=function(mode)
			if mode then
				if cl.rbuffer<mode then
					return
				end
				local txt=cl.rbuffer:sub(1,mode)
				cl.rbuffer=cl.rbuffer:sub(5)
				return txt
			end
			local line,rbuffer=cl.rbuffer:match("^(.-)\r?\n(.*)")
			if line then
				cl.rbuffer=rbuffer
				return line
			end
		end,
	}
	clients[sk]=cl
	receivehead(cl)
	return cl
end

hook.new("select",function(rq,sq)
	for k,v in pairs(sq) do
		if type(v)~="number" then
			if buffering[v] then
				buffering[v].send()
			end
		end
	end
	for k,v in pairs(rq) do
		if clients[v] then
			local cl=clients[v]
			local s2,err,s=v:receive("*a")
			if err=="closed" then
				cl.close()
			else
				cl.rbuffer=cl.rbuffer..(s or s2)
				if cl.onReceive then
					cl.onReceive()
				end
			end
		end
	end
end,"client socket manager")
