local socket = require("socket") 
local http   = require("socket.http")
local https  = require("ssl.https") 
local ltn12  = require("ltn12")
dofile("lib/json.lua")

local debug = true
local PIN = nil
local httpRequest
local config = loadfile("TQAEconfigs.lua")()
local url = "http://"..config.host..":80/api"
if debug then arg = {"getqa","1090"} end

local function main()
    local cmd = arg[1] -- getqa, getscene, uploadqa
    local id = arg[2] -- QA id
    local data = httpRequest("GET","/quickApp/export/"..id)
    print(data)
end

function httpRequest(method,path,data)
    local req,resp = { headers={}},{}
    req.sink = ltn12.sink.table(resp)
    req.url = url..path
    req.user,req.password = config.user,config.pwd
    data = data and json.encode(data)
    req.headers["Accept"] = "*/*"
    req.headers["Content-Type"] = "application/json"
    req.headers["X-Fibaro-Version"] = 2
    req.headers["Fibaro-User-PIN"] = pin
    req.timeout = 20
    req.method=method
    if req.method=="PUT" or req.method=="POST" then
        req.data = data or "[]"
        req.headers["content-length"] = #data
        req.source = ltn12.source.string(data)
    else req.headers["Content-Length"]=0 end
    if req.url:sub(1,5)=="https" then
      _,status,h = https.request(req)
    else
      _,status,h = http.request(req)
    end
    if tonumber(status) and status < 300 then 
      return resp[1] and table.concat(resp) or nil,status,h 
    else return nil,status,h,resp end
end

main()