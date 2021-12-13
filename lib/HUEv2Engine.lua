-- luacheck: globals ignore quickApp plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator HUEv2Engine fibaro
-- luacheck: ignore 212/self

local version = 0.2
local v2 = "1948086000"
local debug = { info = true, call=true, event=true, v2api=true, logger=true }
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

--[[
Room--+
      |             +------ Service A
      |             |
      +---Device ---+
                    |
                 +--+------ Service B
                 |
Zone-------------+
                 |
                 +----- Service - Grouped Light
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
          local d = Resources[e2.id]
          if d.event then 
            DEBUG('event',"Event id:%s type:%s",d.shortId,Resources[e2.id].rType)--,json.encode(e2))
            d:event(e2)
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

--[[
{
"dimming":{"brightness":58.66}, // color,color_temperature,on
"owner":{"rtype":"device","rid":"8dddf049-0a73-44e2-8fdd-e3c2310c1bb1"},
"type":"light",
"id_v1":"/lights/5",
"id":"fb31c148-177b-4b52-a1a5-e02d46c1c3dd"
}
--]]

function ServiceType.light(id,s,d)
  s.props = { on=true, brightness=true, colorTemp=true, colorXY=true }
  s.actions = {
    isOn=true, turnOn=true, turnOff=true, getBrightness=true, setBrightness=true,
    getColorTemp=true, setColorTemp=true, getXY=true, setXY=true, getRGB=true, setRGB=true
  }

  s.path = "/clip/v2/resource/light/"..id
  s.id_v1 = d.id_v1
  s.min_dim = d.dimming and d.dimming.min_dim_level or 0
  s.gamut = d.color and d.color.gamut_type
  s.min_mirek = d.color_temperature and d.color_temperature.mirek_schema.mirek_minimum
  s.max_mirek = d.color_temperature and d.color_temperature.mirek_schema.mirek_maximum
  if s.gamut then s.rgbConv = fibaro.colorConverter.xy(s.gamut) end
  function s:event(ev) dispatch(ev,s) end
  function s:onEvent(ev) self.prop.on = ev.on self:notify({type='on',value=self.prop.on}) end
  function s:colorEvent(ev) self.prop.colorXY = ev.xy self:notify({type='colorXY',value=self.prop.colorXY}) end
  function s:dimEvent(ev) self.prop.brightness = ev.brightness self:notify({type='brightness',value=self.prop.brightness}) end
  function s:colorTempEvent(ev) 
    if ev.mirek_valid then self.prop.colorTemp = ev.mirek self:notify({type='colorTemp',value=self.prop.colorTemp}) end
  end

  function s:turnOn() 
    huePUT(self.path,{on={on=true}}) 
    if OPTIMISTIC then self:onEvent({on=true}) end
  end
  function s:turnOff() 
    huePUT(self.path,{on={on=false}})
    if OPTIMISTIC then self:onEvent({on=false}) end
  end
  function s:setBrightness(v) 
    huePUT(self.path,{dimming={brightness=v}}) 
    if OPTIMISTIC then self:dimEvent({brightness=v}) end
  end
  function s:setColorTemp(t) 
    huePUT(self.path,{color_temperature={mirek=math.floor(t)}})
    if OPTIMISTIC then self:colorTempEvent({mirek=t}) end
  end
  function s:setColorXY(xy) 
    huePUT(self.path,{color={xy=xy}})
    if OPTIMISTIC then self:colorEvent({xy=xy}) end
  end
  function s:setRGB(r,g,b) 
    local xy = s.rgbConv.rgb2xy(r,g,b)
    self:setColorXY(xy)
  end
  function s:isOn() return self.prop.on end
  function s:getXY() return self.prop.colorXY end
  function s:getRGB() return s.rgbConv.xyb2rgb(self.prop.colorXY.x,self.prop.colorXY.y,self.prop.brightness/100.0) end
  function s:getBrigthness() return self.prop.brightness end
  function s:getColorTemp() return self.prop.colorTemp end

  function s:toString() return fmt("Light:%s - %s",id,self.prop.on and "on" or "off") end
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
  s.props = { groupOn=true }
  s.actions = { turnGroupOn=true, turnGroupOff=true, isGroupOn=true }
  s.path = "/clip/v2/resource/grouped_light/"..id
  function s:event(ev) self.prop.groupOn = ev.on self:notify({type='groupOn',value=self.prop.groupOn}) end
  function s:isGroupOn() return self.prop.groupOn end
  function s:turnGroupOn() huePUT(self.path,{on={on=true}}) end
  function s:turnGroupOff() huePUT(self.path,{on={on=false}}) end
  function s:toString() return fmt("Group:%s - %s",self.id,self.prop.on and "on" or "off") end
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

--[[
{
"type":"light_level",
"light":{"light_level":0,"light_level_valid":true},
"owner":{"rtype":"device","rid":"9222ea53-37a6-4ac0-b57d-74bca1cfa23f"},
"id_v1":"/sensors/7",
"id":"a7295dae-379b-4d61-962f-6f9ad9426eda"
}
--]]

--[[
{
"type":"motion",
"motion":{"motion":false,"motion_valid":true},
"owner":{"rtype":"device","rid":"9222ea53-37a6-4ac0-b57d-74bca1cfa23f"},
"id_v1":"/sensors/6","id":"6356a5c3-e5b7-455c-bf54-3af2ac511fe6"
}
--]]

--[[
{
"type":"device_power",
"power_state":{"battery_state":"normal","battery_level":76},
"owner":{"rtype":"device","rid":"a007e50b-0bdd-4e48-bee0-97636d57285a"},
"id_v1":"/sensors/2",
"id":"d6bc1f77-4603-4036-ae5f-28b16eefe4b5"
}
--]]

--[[
{
"type":"zigbee_connectivity",
"owner":{"rtype":"device","rid":"3ab27084-d02f-44b9-bd56-70ea41163cb6"},
"status":"connected",  // "status":"connectivity_issue"
"id_v1":"/lights/9",
"id":"c024b020-395d-45a4-98ce-9df1409eda30"
}
--]]

----------------- Flavours for Hue devices ------------------------

local function setParent(d,id)
  d.parents = d.parents or {}   -- Allow multiple parents
  if id then d.parents[id]=d end
end

local function addChildren(p,typ)
  --p.childs = p.childs or {}
  for _,c in ipairs(p[typ]) do   -- children or services
    local dp = Resources[c.rid]
    setParent(dp,p.id)
    --p.childs[c.rid]=dp
  end
end

local function propagator(d)
  setParent(d,d.owner and d.owner.rid)
  function d:handleEvent(ev)
    for p,_ in pairs(self.parents) do
      p = Resources[p]
      if p and p.handleEvent then p:handleEvent(ev) end
    end
  end
  return d
end

local function subscription(d)
  d.subscribers = {}
  function d:addListener(prop,fun)
    self.subscribers[prop]=self.subscribers[prop] or {}
    self.subscribers[prop][fun]=true 
  end
  function d:notify(prop,ev)
    for s,_ in pairs(self.subscribers[prop] or {}) do s(ev.id,ev.value) end
  end
  local oldHandler = d.handleEvent
  function d:handleEvent(ev)
    if oldHandler then oldHandler(self,ev) end
    self:notify(ev.type,ev)
  end
  return d
end

local function aggregator(d)
  d.props = d.props or {}
  local oldHandler = d.handleEvent
  function d:handleEvent(ev)
    d.props[ev.type]=d.props[ev.type] or {}
    d.props[ev.type][ev.id]=ev.value
    oldHandler(self,ev)
  end
  function d:notify(prop,ev)
    local tp,n = type(ev.value),0
    local val = tp=='boolean' and true or 0
    for id,v in pairs(d.props[prop]) do
      if tp=='number' then val = val+v n=n+1
      elseif tp=='boolean' then val = val and v end
    end
    if tp =='number' then val = val/n end
    for s,_ in pairs(self.subscribers[prop] or {}) do s(ev.id,val) end
  end
  addChildren(d,'services')
  return d
end

local function propOwner(d)
  d.props = d.props or {}
  local oldHandler = d.handleEvent
  function d:handleEvent(ev)
    d.props[ev.type]=ev.value
    oldHandler(self,ev)
  end
  return d
end

local function logger(d)
  local oldHandler = d.handleEvent
  function d:handleEvent(ev)
    DEBUG('logger',"%s => %s",self:toString(),json.encode(ev))
    oldHandler(self,ev)
  end
  return d
end

local function namer(d)
  local pd = d.product_data
  if pd then d.rType = pd.product_name or "" else d.rType = d.type end
  d.rName = d.metadata and d.metadata.name or d.rType
  d.shortId = d.id:match("%-([^%-]+)$")
  function d:toString() return fmt("%s %s",self.shortId,self.rName) end
  return d
end

----------------------- Annotate Hue devices with their flavours ---------------------------------

local HueTypeAnnotation = {}

local function hueAnnotator(d)
  if HueTypeAnnotation[d.type] then 
    namer(d)
    HueTypeAnnotation[d.type](d)
  end
end

function HueTypeAnnotation.temperature(d)
  function d:event(ev)
    self:handleEvent({type='temperature', value=ev.temperature.temperature,id=self.id})
  end
  return propagator(d)
end

function HueTypeAnnotation.zigbee_connectivity(d) 
  function d:event(ev)
    self:handleEvent({type='connected', value=ev.status=='connected' ,id=self.id})
  end
  return propagator(d)
end

function HueTypeAnnotation.light_level(d)
  function d:event(ev)
    local lux =  math.floor(0.5+math.pow(10, (ev.light.light_level - 1) / 10000)) 
    self:handleEvent({type='lux', value=lux,id=self.id})
  end
  return propagator(d) 
end

local lightEventMap = {
  on = 'onEvent', color='colorEvent', dimming='dimEvent', color_temperature='colorTempEvent'
}

function HueTypeAnnotation.light(d)
  s.fActions = {
    isOn=true, turnOn=true, turnOff=true, getBrightness=true, setBrightness=true,
    getColorTemp=true, setColorTemp=true, getXY=true, setXY=true, getRGB=true, setRGB=true
  }
  d.path = "/clip/v2/resource/light/"..d.id
  d.min_dim = d.dimming and d.dimming.min_dim_level or 0
  d.gamut = d.color and d.color.gamut_type
  d.min_mirek = d.color_temperature and d.color_temperature.mirek_schema.mirek_minimum
  d.max_mirek = d.color_temperature and d.color_temperature.mirek_schema.mirek_maximum
  if d.gamut then d.rgbConv = fibaro.colorConverter.xy(d.gamut) end
  
  function d:event(ev)
    for name,h in pairs(lightEventMap) do if ev[name] then d[h](d,ev[name]) end end
  end
  function d:onEvent(ev) self:handleEvent({type='on',value=ev.on,id=self.id}) end
  function d:colorEvent(ev) self:handleEvent({type='colorXY',value=ev.xy,id=self.id}) end
  function d:dimEvent(ev) self:handleEvent({type='brightness',value=ev.brightness,id=self.id}) end
  function d:colorTempEvent(ev) if ev.mirek_valid then self:handleEvent({type='colorTemp',value=ev.mirek,id=self.id}) end end
  
 function d:turnOn() 
    huePUT(self.path,{on={on=true}}) 
    if OPTIMISTIC then self:onEvent({on=true}) end
  end
  function d:turnOff() 
    huePUT(self.path,{on={on=false}})
    if OPTIMISTIC then self:onEvent({on=false}) end
  end
  function d:setBrightness(v) 
    huePUT(self.path,{dimming={brightness=v}}) 
    if OPTIMISTIC then self:dimEvent({brightness=v}) end
  end
  function d:setColorTemp(t) 
    huePUT(self.path,{color_temperature={mirek=math.floor(t)}})
    if OPTIMISTIC then self:colorTempEvent({mirek=t}) end
  end
  function d:setColorXY(xy) 
    huePUT(self.path,{color={xy=xy}})
    if OPTIMISTIC then self:colorEvent({xy=xy}) end
  end
  function d:setRGB(r,g,b) 
    local xy = self.rgbConv.rgb2xy(r,g,b)
    self:setColorXY(xy)
  end
  function d:isOn() return self.prop.on end
  function d:getXY() return self.prop.colorXY end
  function d:getRGB() return self.rgbConv.xyb2rgb(self.prop.colorXY.x,self.prop.colorXY.y,self.prop.brightness/100.0) end
  function d:getBrigthness() return self.prop.brightness end
  function d:getColorTemp() return self.prop.colorTemp end
  
  return propagator(d)
end

function HueTypeAnnotation.motion(d) 
  function d:event(ev)
    self:handleEvent({type='motion', value=ev.motion.motion,id=self.id})
  end
  return propagator(d) 
end

function HueTypeAnnotation.grouped_light(d) 
  function d:event(ev)
    if ev.on~= nil then self:handleEvent({type='groupedOn',value=ev.on.on,id=self.id}) end
  end
  d.fActions = { turnGroupOn=true, turnGroupOff=true, isGroupOn=true }
  d.path = "/clip/v2/resource/grouped_light/"..d.id
  function d:isGroupOn() return self.prop.groupOn end
  function d:turnGroupOn() huePUT(self.path,{on={on=true}}) end
  function d:turnGroupOff() huePUT(self.path,{on={on=false}}) end
  return propagator(d)
end

function HueTypeAnnotation.device_power(d) 
  function d:event(ev)
    self:handleEvent({type='battery',value=ev.power_state.battery_level,id=self.id})
  end
  return propagator(d)
end

function HueTypeAnnotation.button(d) 
  d.buttonId = d.metadata.control_id
  function d:event(ev)
    if ev.button then
      local b = {type='button',id=self.id,value={id=self.buttonId,value=ev.button.last_event, timestamp=os.time()} }
      self:handleEvent(b)
    end
  end
  return propagator(d) 
end

function HueTypeAnnotation.device(d) return logger(propOwner(subscription(propagator(d)))) end
function HueTypeAnnotation.zone(d) return logger(aggregator(subscription(d))) end
function HueTypeAnnotation.room(d) return logger(aggregator(subscription(d))) end 

function HueTypeAnnotation.geolocation(d) return propagator(d) end
function HueTypeAnnotation.entertainment(d) return d end
function HueTypeAnnotation.scene(d) return d end
function HueTypeAnnotation.homekit(d) return d end
function HueTypeAnnotation.bridge_home(d) return d end
function HueTypeAnnotation.bridge(d) return d end
function HueTypeAnnotation.behaviour_script(d) return d end

---------------------------------------------------------------------------

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
  for _,d in pairs(Resources) do hueAnnotator(d) end
  for _,d in pairs(Resources) do if d.event then d:event(d) end end
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
function HUEv2Engine:getResource(id) return Resources[id] end

function HUEv2Engine:dumpDevices()
  local  r = makePrintBuffer("\n")
  for _,d in pairs(HUEv2Engine:getDevices()) do
    r:out(d:toString(),"\n")
  end
  print(r:toString())
end

function HUEv2Engine:listAllDevices(groups)
  local  r = makePrintBuffer("\n")
  r:out("HueTable = {\n")
  local rs = {}
  for _,d in pairs(HUEv2Engine:getResources()) do
    if d.type=='device' or d.type=='room' or d.type=='zone' then
      local name = d.metadata and  d.metadata.name or ""
      local typ = d.product_data and d.product_data.product_name or d.type
      rs[#rs+1]={name=name,type=typ,d=d}
    end
  end
  table.sort(rs,function(a,b) return a.type < b.type or a.type == b.type and a.name < b.name end)
  for _,d0 in pairs(rs) do
    local d = d0.d
    if d.type == 'device' then
      local name = d.metadata and  d.metadata.name or ""
      local pd = d.product_data or {}
      local typ = pd.product_name or ""
      local model = pd.model_id or ""
      r:printf("   ['%s'] = {type='%-17s', name='%-20s', model='%s'},\n",d.id,typ,name,model)
    elseif d.type == 'room' or d.type == 'zone' then
      local name = d.metadata and  d.metadata.name or ""
      local typ = d.type
      r:printf("   ['%s'] = {type='%-17s', name='%-20s'},\n",d.id,typ,name)
    end
  end
  r:out("}\n")
  print(r:toString())
end

HUEv2Engine.xyColors = {
-- Red
  lightsalmon	= {x=0.5015,y=0.3530},
  salmon= {x=0.5347,y=0.3256},
  darksalmon = {x=0.4849,y=0.3476},
  lightcoral = {x=0.5065,y=0.3145},
  indianred	= {x=0.5475,y=0.3113},
  crimson	= {x=0.6435,y=0.3045},
  firebrick	= {x=0.6554,y=0.3111},
  red	= {x=0.675,y=0.322},
  darkred	= {x=0.675,y=0.322},
-- Orange
  coral	= {x=0.5754,y=0.3480},
  tomato= {x=0.6111,y=0.3260},
  orangered	= {x=0.6725,y=0.3230},
  gold= {x=0.4852,y=0.4619},
  orange= {x=0.5567,y=0.4091},
  darkorange = {x=0.5921,y=0.3830},
--Yellow
  lightyellow	= {x=0.3435,y=0.3612},
  lemonchiffon = {x=0.3594,y=0.3756},
  lightgoldenrodyellow	= {x=0.3502,y=0.3715},
  papayawhip = {x=0.3598,y=0.3546},
  moccasin	= {x=0.3913,y=0.3755},
  peachpuff	= {x=0.3948,y=0.3597},
  palegoldenrod	= {x=0.3762,y=0.3978},
  khaki	= {x=0.4023,y=0.4267},
  darkkhaki	= {x=0.4019,y=0.4324},
  yellow	= {x=0.4325,y=0.5007},
-- Green
  lawngreen	= {x=0.4091,y=0.518},
  chartreuse	= {x=0.4091,y=0.518},
  limegreen	= {x=0.4091,y=0.518},
  lime	= {x=0.4091,y=0.518},
  forestgreen	= {x=0.4091,y=0.518},
  green	= {x=0.4091,y=0.518},
  darkgreen	= {x=0.4091,y=0.518},
  greenyellow	= {x=0.4091,y=0.518},
  yellowgreen	= {x=0.4091,y=0.518},
  springgreen	= {x=0.3883,y=0.4771},
  mediumspringgreen	= {x=0.3620,y=0.4250},
  lightgreen	= {x=0.3673,y=0.4356},
  palegreen	= {x=0.3674,y=0.4358},
  darkseagreen	= {x=0.3423,y=0.3862},
  mediumseagreen	= {x=0.3584,y=0.4180},
  seagreen	= {x=0.3580,y=0.4172},
  olive	= {x=0.4325,y=0.5007},
  darkolivegreen	= {x=0.3886,y=0.4776},
  olivedrab	= {x=0.4091,y=0.518},
-- Cyan
  lightcyan	= {x=0.3096,y=0.3216},
  cyan	= {x=0.2857,y=0.2744},
  aqua	= {x=0.2857,y=0.2744},
  aquamarine	= {x=0.3230,y=0.3480},
  mediumaquamarine	= {x=0.3231,y=0.3483},
  paleturquoise	= {x=0.3032,y=0.3090},
  turquoise	= {x=0.3005,y=0.3036},
  mediumturquoise	= {x=0.2937,y=0.2902},
  darkturquoise	= {x=0.2834,y=0.2698},
  lightseagreen	= {x=0.2944,y=0.2916},
  cadetblue	= {x=0.2963,y=0.2953},
  darkcyan	= {x=0.2857,y=0.2744},
  teal	= {x=0.2857,y=0.2744},
-- Blue
  powderblue	= {x=0.3015,y=0.3057},
  lightblue	= {x=0.2969,y=0.2964},
  lightskyblue	= {x=0.2706,y=0.2447},
  skyblue	= {x=0.2788,y=0.2630},
  deepskyblue	= {x=0.2425,y=0.1892},
  lightsteelblue	= {x=0.2926,y=0.2880},
  dodgerblue	= {x=0.2124,y=0.1297},
  cornflowerblue	= {x=0.2355,y=0.1753},
  steelblue	= {x=0.2491,y=0.2021},
  royalblue	= {x=0.2051,y=0.1152},
  blue	= {x=0.167,y=0.04},
  mediumblue	= {x=0.167,y=0.04},
  darkblue	= {x=0.167,y=0.04},
  navy	= {x=0.167,y=0.04},
  midnightblue	= {x=0.1821,y=0.0698},
  mediumslateblue	= {x=0.2186,y=0.1419},
  slateblue	= {x=0.2198,y=0.1443},
  darkslateblue	= {x=0.2235,y=0.1502},
-- Purple
  lavender	= {x=0.3085,y=0.3071},
  thistle	= {x=0.3342,y=0.2970},
  plum	= {x=0.3495,y=0.2545},
  violet	= {x=0.3645,y=0.2128},
  orchid	= {x=0.3716,y=0.2102},
  fuchsia	= {x=0.3826,y=0.1597},
  magenta	= {x=0.3826,y=0.1597},
  mediumorchid	= {x=0.3362,y=0.1743},
  mediumpurple	= {x=0.2629,y=0.1772},
  blueviolet	= {x=0.2524,y=0.1062},
  darkviolet	= {x=0.2852,y=0.1086},
  darkorchid	= {x=0.2986,y=0.1335},
  darkmagenta	= {x=0.3826,y=0.1597},
  purple	= {x=0.3826,y=0.1597},
  indigo	= {x=0.2485,y=0.0917},
--Pink
  pink	= {x=0.3947,y=0.3114},
  lightpink	= {x=0.4105,y=0.3102},
  hotpink	= {x=0.4691,y=0.2468},
  deeppink	= {x=0.5388,y=0.2464},
  palevioletred	= {x=0.4657,y=0.2773},
  mediumvioletred	= {x=0.4997,y=0.2247},
-- White
  white	= {x=0.3227,y=0.3290},
  snow	= {x=0.3280,y=0.3286},
  honeydew	= {x=0.3210,y=0.3441},
  mintcream	= {x=0.3162,y=0.3346},
  azure	= {x=0.3125,y=0.3274},
  aliceblue	= {x=0.3098,y=0.3220},
  ghostwhite	= {x=0.3098,y=0.3220},
  whitesmoke	= {x=0.3227,y=0.3290},
  seashell	= {x=0.3385,y=0.3353},
  beige	= {x=0.3401,y=0.3559},
  oldlace	= {x=0.3377,y=0.3376},
  floralwhite	= {x=0.3349,y=0.3388},
  ivory	= {x=0.3327,y=0.3444},
  antiquewhite	= {x=0.3546,y=0.3488},
  linen	= {x=0.3410,y=0.3386},
  lavenderblush	= {x=0.3357,y=0.3226},
  mistyrose	= {x=0.4212,y=0.1823},
}