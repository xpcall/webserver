local function defHeaders()
	return {
		server=config.customServerHeader or ("PTServ "..version),
		connection="keep-alive"
	}
end

local codes={
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
	res.code=tonumber(res.code) or 200
	local out="HTTP/1.1 "..res.code.." "..codes[res.code].."\r\n"
	res.data=res.data or ""
	if not headers["Content-Length"] and res.data then
		headers["Content-Length"]=#res.data
	end
	for k,v in pairs(headers) do
		out=out.k..": "..tostring(v).."\r\n"
	end
	cl.send(out.."\r\n")
end

function serveres(cl,res)
	servehead(cl,res)
	if cl.method~="head" then
		out=out..res.data
	end
	cl.send(out)
	receivehead(cl) -- keep-alive
end

local largef={}

function serve(cl)
	local headers=res.headers
	if cl.method~="post" and cl.method~="get" and cl.method~="head" then
		local res={
			code=405,
			headers=defHeaders(),
		}
		res.headers.allowed="GET, POST, HEAD"
		return serveres(cl,res)
	end
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
		runlua(fs.read(path),cl,res)
	else
		servehead()
		if fs.size(path)>16384 then
			if largef[path] then
				table.insert(largef[path],{cl,res})
			else
				hook.new(hook.timer(0.5),function()

				end)
			end
		end
	end
end

