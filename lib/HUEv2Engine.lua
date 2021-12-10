-- luacheck: globals ignore quickApp plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator HUEv2Engine fibaro
-- luacheck: ignore 212/self

local version = 0.2
local v2 = "1948086000"
local debug = { info = true, call=true, event=true, v2api=true }
local OPTIMISTIC = false
local app_key,url,callBack
local fmt = string.format
local err_retry = 3
local Devices,Rooms,Zones,Scenes,Lights,Buttons,Motions,Temperatures = {},{},{},{},{},{},{},{}
local devFilter
local Resources,ResourceMap = {},{}
local ResourcesType = { 
  device = Devices, room = Rooms, zone = Zones, scene = Scenes, 
  light=Lights, button=Buttons, motion=Motions, temperture=Temperatures
}

--[[
debug.info        -- greetings etc
debug.event       -- incoming event from Hue hub
debug.v2api       -- v2api info (unhandled events etc)
debug.call        -- http calls to Hue hub
debug.unknownType -- Unhandled device updates
--]]

local function DEBUG(tag,str,...) if debug[tag] then quickApp:debug(fmt(str,...)) end end
local function ERROR(str,...) quickApp:error(fmt(str,...)) end
local function WARNING(str,...) quickApp:warning(fmt(str,...)) end

local function makePrintBuffer(e)
  local b,r = {},e  and {e} or {}
  function b:toString() return table.concat(r) end
  function b:printf(str,...) r[#r+1]=fmt(str,...) end
  function b:out(...) for  _,e1 in ipairs({...}) do r[#r+1]=e1 end end
  return b
end

local function fetchEvents()
  local getw
  local eurl = url.."/eventstream/clip/v2"
  local args = { options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = app_key }}}
  function args.success(res)
    local data = json.decode(res.data)
    for _,e1 in ipairs(data) do
      if e1.type=='update' then
        for _,e2 in ipairs(e1.data) do
          if ResourceMap[e2.id] then 
            DEBUG('event',"Event id:%s type:%s",e2.id,ResourceMap[e2.id].type)--,json.encode(e2))
            ResourceMap[e2.id]:event(e2)
          else
            local _ = 0
            if debug.unknownType then WARNING("Unknow resource type: %s",json.encode(e1)) end
          end
        end
      else
        DEBUG('v2api',"New v2 event type: %s",e1.type)
        DEBUG('v2api',"%s",json.encode(e1))
      end
    end
    getw()
  end
  function args.error(err) if err~="timeout" then ERROR("/eventstream: %s",err) end getw() end
  function getw() net.HTTPClient():request(eurl,args) end
  setTimeout(getw,0)
end

local EVENTS = {}
local function post(ev,t) 
  ev=type(ev)=='string' and {type=ev} or ev
  setTimeout(function() EVENTS[ev.type](ev) end,t or 0) 
end

local function hueGET(api,event) 
  net.HTTPClient():request(url..api,{
      options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = app_key }},
      success = function(res) post({type=event,result=json.decode(res.data)}) end,
      error = function(err) post({type=event,error=err})  end,
    })
end

local function huePUT(path,data,op)
  DEBUG('call',"%s %s",path,json.encode(data))
  net.HTTPClient():request(url..path,{
      options = { method=op or 'PUT', data=data and json.encode(data), checkCertificate=false, headers={ ['hue-application-key'] = app_key }},
      success = function(_)  end,
      error = function(err) ERROR("hue call, %s %s - %s",path,json.encode(data),err) end,
    })
end

local ServiceType = {}

--[[
{
"dimming":{"brightness":58.66}, // color,color_temperature,on
"owner":{"rtype":"device","rid":"8dddf049-0a73-44e2-8fdd-e3c2310c1bb1"},
"type":"light",
"id_v1":"/lights/5",
"id":"fb31c148-177b-4b52-a1a5-e02d46c1c3dd"
}
--]]

local function addParent(s,p) s.parents[#s.parents+1]=p return s end
local function notifyParents(s,prop,v) for _,p in ipairs(s.parents) do p:setProp(prop,v) end end
local function setParentService(name,s) for _,p in ipairs(s.parents) do p[name]=s end end

local eventMap = {
  on = 'onEvent', color='colorEvent', dimming='dimEvent', color_temperature='colorTempEvent'
}

local function dispatch(ev,s) 
  for f,e in pairs(eventMap) do 
    local se = ev[f]
    if se then
      if s[e] then s[e](s,se) else WARNING("Unknown event for %s - %s",s:toString(),json.encode(ev)) end
    end
  end
end

function ServiceType.light(id,s,d)
  setParentService("lightService",s)
  s.path = "/clip/v2/resource/light/"..id
  s.id_v1 = d.id_v1
  s.min_dim = d.dimming and d.dimming.min_dim_level or 0
  s.gamut = d.color and d.color.gamut_type
  s.min_mirek = d.color_temperature and d.color_temperature.mirek_schema.mirek_minimum
  s.max_mirek = d.color_temperature and d.color_temperature.mirek_schema.mirek_maximum
  if s.gamut then s.rgbConv = fibaro.colorConverter.xy(s.gamut) end
  function s:event(ev) dispatch(ev,s) end
  function s:onEvent(ev) self.on = ev.on notifyParents(s,'on',self.on) end
  function s:colorEvent(ev) self.xy = ev.xy notifyParents(s,'colorXY',self.xy) end
  function s:dimEvent(ev) self.brightness = ev.brightness notifyParents(s,'brightness',self.brightness) end
  function s:colorTempEvent(ev) 
    if ev.mirek_valid then self.colorTemp = ev.mirek notifyParents(s,'colorTemp',self.colorTemp) end
  end
  function s:turnOn() 
    huePUT(self.path,{on={on=true}}) 
    if OPTIMISTIC then self:onEvent({on=true}) end
  end
  function s:turnOff() 
    huePUT(self.path,{on={on=false}})
    if OPTIMISTIC then self:onEvent({on=false}) end
  end
  function s:setDimming(v) 
    huePUT(self.path,{dimming={brightness=v}}) 
    if OPTIMISTIC then self:dimEvent({brightness=v}) end
  end
  function s:setTemperature(t) 
    huePUT(self.path,{color_temperature={mirek=math.floor(t)}})
    if OPTIMISTIC then self:colorTempEvent({mirek=t}) end
  end
  function s:setXY(xy) 
    huePUT(self.path,{color={xy=xy}})
    if OPTIMISTIC then self:colorEvent({xy=xy}) end
  end
  function s:setRGB(r,g,b) 
    local xy = s.rgbConv.rgb2xy(r,g,b)
    self:setXY(xy)
  end
  function s:getXY() return self.xy end
  function s:getRGB() 
    return s.rgbConv.xyb2rgb(self.xy.x,self.xy.y,self.brightness/100.0)
  end
  function s:getBrigthness() return self.brightness end
  function s:getColorTemp() return self.colorTemp end
  function s:isOn() return self.on end

  function s:toString() return fmt("Light:%s %s",id,self.on and "ON" or "OFF") end
  function s:addMethods(d1)
    for _,m in ipairs({
        "isOn","turnOn","turnOff","getBrightness","getColorTemp",
        "setRGB","getXY","getRGB","setTemperature","setDimming"
        }) do
      d1[m]=function(_,...) return s[m](s,...) end
    end
  end  
  return  s
end

--[[
{
"id_v1":"/groups/5",
"type":"grouped_light",
"on":{"on":true},
"id":"39c94b33-7a3d-48e7-8cc1-dc603d401db2"
}
--]]
function ServiceType.grouped_light(id,s,_)
  setParentService("groupService",s)
  s.path = "/clip/v2/resource/grouped_light/"..id
  function s:event(ev) self.on = ev.on notifyParents(s,'on',self.on) end
  function s:turnOn() huePUT(self.path,{on={on=true}}) end
  function s:turnOff() huePUT(self.path,{on={on=false}}) end
  function s:toString() return fmt("Group:%s",id) end
  function s:addMethods(d) 
    for _,m in ipairs({"isOn","turnOn","turnOff"}) do
      d[m]=function(_,...) return s[m](s,...) end
    end
  end  
  return  s
end

--[[
{
"id":"efc3283b-304f-4053-a01a-87d0c51462c3",
"owner":{"rtype":"device","rid":"a007e50b-0bdd-4e48-bee0-97636d57285a"},
"button":{"last_event":"initial_press"}, // "repeat","long_release","short_release"
"id_v1":"/sensors/2",
"type":"button"
}
--]]
function ServiceType.button(id,s,d)
  setParentService("switchService",s)
  s.buttonId = d.metadata.control_id
  local p = s.parents[1]
  p.buttons = p.buttons or {}
  p.buttons[s.buttonId]=s
  function s:event(ev) 
    if ev.button then
      p.last_button = {event=self.lastEvent,id=s.buttonId}
      self.lastEvent=ev.button.last_event 
      notifyParents(s,'button',p.last_button) 
    end 
  end
  function s:toString() return fmt("Button(%s):%s",s.buttonId,id) end
  function s:addMethods(_) 
    function d.getButton() return p.last_button end 
  end  
  return  s
end

function ServiceType.temperature(id,s,_)
  setParentService("tempService",s)
  function s:event(ev) self.temp = ev.temperature.temperature notifyParents(s,'temp',self.temp)  end
  function s:toString() return fmt("Temp:%s",id) end
  function s:addMethods(d1) 
    function d1.getTemperature() return s.temp end 
  end    
  return  s
end

--[[
{
"type":"light_level",
"light":{"light_level":0,"light_level_valid":true},
"owner":{"rtype":"device","rid":"9222ea53-37a6-4ac0-b57d-74bca1cfa23f"},
"id_v1":"/sensors/7",
"id":"a7295dae-379b-4d61-962f-6f9ad9426eda"
}
--]]
function ServiceType.light_level(id,s,_)
  setParentService("luxService",s)
  function s:event(ev) 
    self.lux = math.floor(0.5+math.pow(10, (ev.light.light_level - 1) / 10000)) 
    notifyParents(s,'lux',self.lux) 
  end
  function s:toString() return fmt("Lux:%s",id) end
  function s:addMethods(d) 
    function d.getLux() return s.lux end 
  end
  return  s
end

--[[
{
"type":"motion",
"motion":{"motion":false,"motion_valid":true},
"owner":{"rtype":"device","rid":"9222ea53-37a6-4ac0-b57d-74bca1cfa23f"},
"id_v1":"/sensors/6","id":"6356a5c3-e5b7-455c-bf54-3af2ac511fe6"
}
--]]
function ServiceType.motion(id,s,_)
  setParentService("motionService",s)
  function s:event(ev) self.motion=ev.motion.motion notifyParents(s,'motion',self.motion)  end
  function s:toString() return fmt("Motion:%s",id) end
  function s:addMethods(d) 
    function d.getMotion() return s.motion end 
  end
  return  s
end

--[[
{
"type":"device_power",
"power_state":{"battery_state":"normal","battery_level":76},
"owner":{"rtype":"device","rid":"a007e50b-0bdd-4e48-bee0-97636d57285a"},
"id_v1":"/sensors/2",
"id":"d6bc1f77-4603-4036-ae5f-28b16eefe4b5"
}
--]]
function ServiceType.device_power(id,s,_)
  setParentService("batteryService",s)
  function s:event(ev) self.battery=ev.power_state.battery_level notifyParents(s,'battery',self.battery) end
  function s:toString() return fmt("Battery:%s",id) end
  function s:addMethods(d)  
    function d.getBattery() return s.battery end 
  end
  return  s
end

--[[
{
"type":"zigbee_connectivity",
"owner":{"rtype":"device","rid":"3ab27084-d02f-44b9-bd56-70ea41163cb6"},
"status":"connected",  // "status":"connectivity_issue"
"id_v1":"/lights/9",
"id":"c024b020-395d-45a4-98ce-9df1409eda30"
}
--]]

function ServiceType.zigbee_connectivity(id,s,_)
  setParentService("connectivityService",s)
  function s:event(ev) self.connected = ev.status=='connected' notifyParents(s,'connected',self.connected)  end
  function s:toString() return fmt("Connectivity:%s",id) end
  function s:addMethods(d) 
    function d.getConnected() return s.connected end 
  end
  return  s
end

function ServiceType.entertainment(id,s,_)
  function s:event(_) --[[print(s.type,s.id,json.encode(ev))--]] end
  function s:toString() return fmt("Entertainment:%s",id) end
  function s:addMethods(_) end
  return  s
end

local function makeService(parent,id,typ)
  if typ == 'bridge' then return end
  local d = ResourceMap[id]
  if d then return addParent(d,parent) end
  d = Resources[id]
  local service = { parents = { parent } }
  service.type = typ
  if ServiceType[typ] then 
    ServiceType[typ](id,service,d)
    service:event(d)
    return service
  else WARNING("Unknown type:%s",typ) end
end

local function addProps(d)
  local listeners = {}
  d.props = {}
  function d:addListener(prop,f) 
    listeners[prop] = f
    if d.props[prop]~= nil then f(prop,d.props[prop])  end 
  end
  function d:setProp(prop,newValue)
    if listeners[prop]==nil then d.props[prop]=newValue return end
    local oldValue = d.props[prop]
    if type(newValue)=='table' then -- Handle table values
      if type(oldValue) == 'table' then
        local flag = true
        for k,v in pairs(newValue) do if oldValue[k]~=v then flag=false break end end
        if flag then return end
      end
    elseif newValue==oldValue then return end
    d.props[prop]=newValue
    listeners[prop](prop,newValue)
  end
end

local function makeGroup(id,d)
  local group = { id = id, name=d.metadata.name, children = {} }
  group.type = d.type
  addProps(group)
  function group:toString()
    local b = makePrintBuffer()
    b:printf("Group:%s '%s' - %s - %s\n",self.id,self.name,self.type) 
    b:printf(" Services:\n") 
    for _,s in pairs(self.children) do
      b:printf("  %s\n",s:toString()) 
    end
    return b:toString()
  end
  for _,s in ipairs(d.services) do
    local service = makeService(group,s.rid,s.rtype)
    group.children[s.rid] = service
    ResourceMap[s.rid] = service
    if s.rtype=='grouped_light' then
      group.group = service
    end
    if service then service:addMethods(group) end
  end
  return group
end

local function makeDevice(id,d)
  local device = { id = id, name=d.metadata.name, children = {} }
  device.type = d.product_data.product_name
  device.model = d.product_data.model_id
  addProps(device)
  function device:toString()
    local b = makePrintBuffer()
    b:printf("Device:%s '%s' - %s - %s\n",self.id,self.name,self.type,self.model) 
    b:printf(" Services:\n") 
    for _,s in pairs(self.children) do
      b:printf("  %s\n",s:toString()) 
    end
    return b:toString()
  end
  for _,s in ipairs(d.services or {}) do
    local service = makeService(device,s.rid,s.rtype)
    device.children[s.rid] = service
    ResourceMap[s.rid] = service
    if service then service:addMethods(device) end
  end
  return device
end

function EVENTS.STARTUP(_) hueGET("/api/config",'HUB_VERSION') end

function EVENTS.HUB_VERSION(ev)
  if ev.error then 
    ERROR("%s",ev.error)
  else
    local res = ev.result
    if res.swversion >= v2 then
      DEBUG('info',"V2 api available (%s)",res.swversion)
      post('REFRESH_RESOURCES')
    else
      WARNING("V2 api not available (%s)",res.swversion)
    end
  end
end

function EVENTS.REFRESH_DEVICES(_) hueGET("/clip/v2/resource",'REFRESHED_DEVICES') end

function EVENTS.REFRESH_RESOURCES(_) hueGET("/clip/v2/resource",'REFRESHED_RESOURCES') end

function EVENTS.REFRESHED_RESOURCES(ev)
  if ev.error then 
    ERROR("/clip/v2/resource %s",ev.error)
    ERROR("Retry in %ss",err_retry)
    post('REFRESH_RESOURCES',1000*err_retry)
  end
  for _,d in ipairs(ev.result.data or {}) do
    Resources[d.id]=d
    ResourcesType[d.type] = ResourcesType[d.type] or {}
    ResourcesType[d.type][d.id]=d
  end
  for id,d in pairs(Devices) do 
    if (devFilter == nil or devFilter[d.id]) then Devices[id]=makeDevice(id,d) else Devices[id]=nil end
  end
  for id,d in pairs(Rooms) do 
    if (devFilter == nil or devFilter[d.id]) then Rooms[id]=makeGroup(id,d) else Rooms[id]=nil end
  end
  for id,d in pairs(Zones) do 
    if (devFilter == nil or devFilter[d.id]) then Zones[id]=makeGroup(id,d) else Zones[id]=nil end
  end
  if callBack then callBack() callBack=nil end
end

HUEv2Engine = { debug=debug }
function HUEv2Engine:initEngine(ip,key,cb)
  devFilter = HUEv2Engine.deviceFilter
  app_key = key
  url =  fmt("https://%s:443",ip)
  DEBUG('info',"HUEv2Engine v%s",version)
  DEBUG('info',"Hub url: %s",url)
  callBack = function() fetchEvents() if cb then cb() end end
  post('STARTUP')
end
function HUEv2Engine:getResources() return Resources end
function HUEv2Engine:getDevices() return Devices end
function HUEv2Engine:getDevice(uid) return Devices[uid] end
function HUEv2Engine:getLights()
end
function HUEv2Engine:getRooms()
end
function HUEv2Engine:getZones()
end
function HUEv2Engine:getMotions()
end
function HUEv2Engine:getSwitches()
end
function HUEv2Engine:getTemperatures()
end

function HUEv2Engine:dumpDevices()
  local  r = makePrintBuffer("\n")
  for _,d in pairs(HUEv2Engine:getDevices()) do
    r:out(d:toString(),"\n")
  end
  print(r:toString())
end

function HUEv2Engine:listAllDevices()
  local  r = makePrintBuffer("\n")
  r:out("HueTable = {\n")
  for _,d in pairs(HUEv2Engine:getResources()) do
    if d.type == 'device' then
      local name = d.metadata and  d.metadata.name or ""
      local pd = d.product_data or {}
      local typ = pd.product_name or ""
      local model = pd.model_id or ""
      r:printf("   ['%s'] = {name='%s', type='%s', model='%s'},\n",d.id,name,typ,model)
    end
  end
  r:out("}\n")
  print(r:toString())
end