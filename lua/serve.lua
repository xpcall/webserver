local function defHeaders()
	return {
		server=config.customServerHeader or ("PTServ "..version),
		connection="keep-alive",
	}
end

head_codes={
	[200]="OK",
	[302]="Found",
	[304]="Not Modified",
	[400]="Bad Request",
	[401]="Unauthorized",
	[403]="Forbidden",
	[404]="Not Found",
	[405]="Method not Allowed",
	[411]="Length Required",
}

local mime={
	["html"]="text/html",
	["lua"]="text/html",
	["css"]="text/css",
	["png"]="image/png",
	["bmp"]="image/bmp",
	["gif"]="image/gif",
	["jpg"]="image/jpeg",
	["jpeg"]="image/jpeg",
	["txt"]="text/plain",
	["zip"]="application/octet-stream",
	["gz"]="application/octet-stream",
	["tar"]="application/octet-stream",
	["exe"]="application/octet-stream",
	["jar"]="application/octet-stream",
	["download"]="application/octet-stream",
}

local function encodeChunked(txt)
	local out=""
	while #txt>1024 do
		out=out.."400\r\n"..txt:sub(1,1024).."\r\n"
		txt=txt:sub(1025)
	end
	return out..string.format("%x",#txt)..txt.."\r\n0\r\n\r\n"
end

function servehead(cl,res)
	local headers=res.headers
	headers["Content-Type"]=headers["Content-Type"] or mime[res.format] or "text/plain"
	if cl.headers["Connection"]=="close" then
		res.headers["Connection"]="close"
	end
	res.code=tonumber(res.code) or 200
	local out="HTTP/1.1 "..res.code.." "..head_codes[res.code].."\r\n"
	res.data=res.data or ""
	if not headers["Content-Length"] and res.data then
		headers["Content-Length"]=#res.data
	end
	for k,v in pairs(headers) do
		out=out..k..": "..tostring(v).."\r\n"
	end
	cl.send(out.."\r\n")
end

function serveres(cl,res)
	local out=""
	servehead(cl,res)
	if cl.method~="head" then
		out=out..(res.headers["Transfer-Encoding"]=="chunked" and encodeChunked(res.data) or res.data)
	end
	cl.onDoneSending=cl.headers["connection"]=="close" and cl.close or receivehead
	cl.send(out)
end

local function err(cl,code)
	local res={
		code=code,
		headers=defHeaders(),
		format="html",
	}
	if code==405 then
		res.headers.allowed="GET, POST, HEAD"
	end
	res.data="<center><h1>Error "..code..": "..assert(head_codes[code],code).."</h1></center>"
	serveres(cl,res)
end

--local largef={}
function serve(cl)
	local domainconf=config.domains[cl.headers["Host"]]
	cl.path=fs.combine(domainconf.dir,cl.path)
	if cl.method~="post" and cl.method~="get" and cl.method~="head" then
		err(405)
	end
	local path=cl.path
	local ext=path:match("%.(.-)$") or "txt"
	local res={
		headers=defHeaders(),
		code=200,
		format=ext,
	}
	if not fs.exists(path) then
		res.code=404
		res.data="<center><h1>404 Not Found</h1></center>"
	elseif ext=="lua" then
		res.format="html"
		return runlua(fs.read(path),cl,res)
	else
		if fs.isDir(path) then
			local found
			local dirout='<h3><a href="..">..</a><br>'
			for k,v in pairs(fs.list(path)) do
				dirout=dirout..'<a href="'..v..'">'..v..'</a><br>'
				if v:match("^index%..+") then
					path=fs.combine(path,v)
					res.format=path:match("%.(.-)$") or "txt"
					found=true
					break
				end
			end
			if not found then
				res.format="html"
				res.data=dirout
				res.code=200
				return serveres(cl,res)
			end
		end
		-- todo: better large file support
		--[[if fs.size(path)>16384 then
			if largef[path] then
				table.insert(largef[path],{cl,res})
			else
				largef[path]={{cl,res}}
				hook.new(hook.timer(0.5),function()
				end)
			end
		end]]
		local nm=(cl.headers["If-None-Match"] or ""):match('^"(%x+)"$')
		if nm then
			if fs.modified(path)==tonumber(nm,16) then
				return err(cl,304)
			end
		end
		res.data=fs.read(path)
		res.headers["ETag"]='"'..string.format("%X",fs.modified(path))..'"'
		res.headers["Cache-Control"]=""
		print("serving "..path)
		serveres(cl,res)
	end
end

