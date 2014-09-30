function urlencode(txt)
	return txt:gsub("\r?\n","\r\n"):gsub("[^%w ]",function(t) return string.format("%%%02X",t:byte()) end):gsub(" ","+")
end

function urldecode(txt)
	return txt:gsub("+"," "):gsub("%%(%x%x)",function(t) return string.char(tonumber("0x"..t)) end)
end

function htmlencode(txt)
	return txt:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub("\"","&quot;"):gsub("'","&apos;"):gsub("\r?\n","<br>"):gsub("\t","    ")
end

function parsepost(url)
	local out={}
	for var,dat in url:gmatch("([^&]+)=([^&]+)") do
		out[urldecode(var)]=urldecode(dat)
	end
	return out
end

function merge(a,b)
	for k,v in pairs(a) do
		if type(v)=="table" and b[k] then
			merge(v,b[k])
		else
			b[k]=v
		end
	end
end