local out=""
local env=setmetatable({
	print=function(...)
		out=out..table.concat({...}," ").."\r\n"
	end,
	write=function(...)
		out=out..table.concat({...}," ")
	end,
},{
	__index=_G,
})
env._G=env
local function err(cl,txt)
	local res={
		headers=defHeaders(),
		code=500,
		data="<html><head><title>Script error</title></head><h1>Script error</h1><br><h3>\n"..htmlencode(txt).."\n</h3></html>",
	}
	servehead(cl,res)
	serveres(cl,res)
end
function runlua(code,cl,res)
	local func,rr=loadstring(code,"="..cl.path)
	if not func then
		return err(cl,rr)
	end
	setfenv(func,env)
	env.cl=cl
	env.res=res
	env.post=cl.post
	env.get=cl.get
	env.headers=res.headers
	out=""
	print("calling func")
	local ok,err=pcall(func)
	if not ok then
		return err(cl,err)
	end
	print("done")
	res.data=out
	serveres(cl,res)
end