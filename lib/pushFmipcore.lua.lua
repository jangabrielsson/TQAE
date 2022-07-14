--[[
Installation:

Install homebrew
Install luarocks
>brew install luarocks
Find out which lua you have installed
>which lua
Ex. /opt/homebrew/bin/lua
Make a symbolic from ~/Documents/LUA to the installed lua
>ln -s ~/Documents/LUA /opt/homebrew/bin/lua
Go into system preferences -> privacy -> privacy and gie the LUA program 'full disk access'
>luarocks install luajson
>brew install openssl
>luarocks install luasec OPENSSL_DIR=/opt/homebrew/opt/openssl@3
>brew install luasocket

Setup variables below and run script
>lua pushFmipcore.lua
--]]

local interval = 10
local macUser = "erajgab"
local HC3user = "admin"
local HC3pwd = "admin"
local HC3host = "192.168.1.57"
local QAname = "testLoc" -- name or id. Should have function QuickApp:FMIPCORE(data) to recieve data
local items = {
  "5D02CA4A-8223-4E66-BBE4-C1CEB6B0AE33", -- Jan's handbag
  "3703DA14-09C6-403E-8E2D-E8704DE17EEA", -- Jan's Apple Watch
}

_,_ = pcall(require,"lib.json")
if not json then
  json = require"json"
end

----------------------------- utils ----------------------------
local fmt = string.format
local function printf(...) print(fmt(...)) end
local function ERROR(...) print("Error:",fmt(...)) end

---------------------------- http ------------------------------
local socket = require("socket") 
local http   = require("socket.http")
local https  = require("ssl.https") 
local ltn12  = require("ltn12")

local function httpRequest(reqs,extra)
  local resp,req,status,h,resetTimeout,timeout,_={},{} 
  for k,v in pairs(extra or {}) do req[k]=v end; for k,v in pairs(reqs) do req[k]=v end
  req.sink,req.headers = ltn12.sink.table(resp), req.headers or {}
  req.headers["Accept"] = req.headers["Accept"] or "*/*"
  req.headers["Content-Type"] = req.headers["Content-Type"] or "application/json"
  if req.timeout then timeout = req.timeout / 1000 end
  resetTimeout,http.TIMEOUT = http.TIMEOUT,timeout
  if req.method=="PUT" or req.method=="POST" then
    req.data = req.data or "[]"
    req.headers["content-length"] = #req.data
    req.source = ltn12.source.string(req.data)
  else req.headers["Content-Length"]=0 end
--  req.url = uriEncode(req.url)
  if req.url:sub(1,5)=="https" then
    _,status,h = https.request(req)
  else
    _,status,h = http.request(req)
  end
  if resetTimeout then http.TIMEOUT = resetTimeout end
  if tonumber(status) and status < 300 then 
    return resp[1] and table.concat(resp) or nil,status,h 
  else return nil,status,h,resp end
end

local base = "http://"..HC3host.."/api"
local function HC3Request(method,path,data,extra)
  local req = {method=method, url=(extra and extra.base or base)..path,
    user=HC3user, password=HC3pwd, data=data and json.encode(data) or nil, timeout = 15000, 
    headers = {["Accept"] = '*/*',["X-Fibaro-Version"] = 2},
  }
  for k,v in pairs(extra or {}) do req[k]=v end
  local res,stat,headers,_ = httpRequest(req)
  if res~=nil then
    local a,b = pcall(json.decode,res)
    if a then return b,stat,headers
    else
      ERROR("Bad HC3 call: %s",path)
      return nil,500,headers
    end
  else 
    if tonumber(stat) and (stat > 400 and stat < 403) then 
      ERROR("Bad credential when logging in to HC3, exiting to avoid account lockout")
      os.exit()
    end
    if tonumber(stat) and stat > 209 then
      ERROR("api","error","Bad HC3 call: %s (%s)",path,stat)
    end
    return nil,stat,headers 
  end
end

-------- main ---------------------------------------------
debug=true
version = 0.2

local tracking = 0
local fmipPath = fmt("/Users/%s/Library/Caches/com.apple.findmy.fmipcore",macUser)
if debug then fmipPath="/Users/erajgab/Documents/GitHub/TQAE/test" end

local t = {}
for _,n in ipairs(items) do t[n]={} tracking = tracking+1 end
items = t

local function itemFun(d)
  return {type='item',id=d.identifier,name=d.name,owner=d.owner,address=d.address,location=type(d.location)=='table' and d.location or nil}
end

local function deviceFun(d)
  return {type='device',id=d.baUUID or d.UUID or d.id,name=d.name,address=d.address,batteryLevel=d.batteryLevel,batteryStatus=d.batteryStatus,location=type(d.location)=='table' and d.location or nil}
end

local function getData()
  local file,err = io.open(fmipPath.."/Items.data","r")
  assert(err==nil,"Opening "..fmipPath.."/Items.data".." "..(err or ""))
  local itemData = file:read("*all")
  file:close()
  file,err = io.open(fmipPath.."/Devices.data","r")
  assert(err==nil,"Opening "..fmipPath.."/Devices.data".." "..(err or ""))
  local deviceData = file:read("*all")
  file:close()
  return json.decode(itemData),json.decode(deviceData)
end

local QAid
if tonumber(QAname) then
  local a,b = HC3Request("GET","/devices/"..QAname)
  QAid = a.id
else
  local a,b = HC3Request("GET","/devices?name="..QAname)
  QAid = a[1].id
end

print(string.rep("-",10).." pushFmipcore v"..version..string.rep("-",10))
printf("QA id is %s",QAid)
printf("Tracking %s devices",tracking)
printf("Watching every %ss",interval)
printf(string.rep("-",40))

local itemData,deviceData = getData()

printf("All device:")
for _,item in ipairs(itemData) do
  printf("%s, %s, %s, %s",item.identifier,item.name,item.owner,os.date("%c",item.location.timestamp))
end

for _,item in ipairs(deviceData) do
  if all then
    printf("%s, %s, %s, location=%s",item.baUUID or item.UUID or item.id,item.name,item.deviceDisplayName,item.location~=nil)
  elseif type(item.location)=='table' then
    printf("%s, %s, %s, %s",item.baUUID or item.UUID or item.id,item.name,item.deviceDisplayName,os.date("%c",item.location.timestamp))
  end

end
printf(string.rep("-",40))

local function changed(a,b)
  local bat=a.batteriLevel ~= b.batteriLevel or a.batteriStatus ~= b.batteriStatus
  return a.location.longitude ~= b.location.longitude or b.location.latitude ~= a.location.latitude or bat
end

while true do
  local itemData,deviceData = getData()
  local changes = 0
  for _,item in ipairs(itemData) do
    item = itemFun(item)
    if items[item.id] and item.location then
      local it = items[item.id]
      if it.location==nil or changed(it,item) then
        items[item.id] = item
        item.new = true
        changes = changes+1
      end
    end
  end
  for _,item in ipairs(deviceData) do
    item = deviceFun(item)
    if items[item.id] and item.location then
      local it = items[item.id]
      if it.location==nil or changed(it,item) then
        items[item.id] = item
        item.new = true
        changes = changes+1
      end
    end
  end

  printf("%s changed items/devices",changes > 0 and changes or "No")

  local newItems = {}
  for id,item in pairs(items) do
    local d = {}
    if item.new then
      printf("New:%s %s %s",item.name,item.location.longitude,item.location.latitude)
      newItems[#newItems+1]=item
    end
    item.new=nil
  end
  if newItems[1] then
    HC3Request("POST","/devices/"..QAid.."/action/FMIPCORE",{args={json.encode(newItems)}})
  end
  socket.sleep(interval)
end


