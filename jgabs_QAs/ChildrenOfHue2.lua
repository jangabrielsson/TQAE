-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDeviceQA MotionSensorQA TempSensorQA LuxSensorQA ButtonQA
-- luacheck: globals ignore LampQA ColorLampQA DimLampQA WhiteLampQA 

_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  copas=true,
  debug = { onAction=true, http=false, UIEevent=true, refreshStates=false },
}

--%%name="HueTest"
--%%quickVars = {["Hue_IP"]=EM.cfg.Hue_IP,["Hue_User"]=EM.cfg.Hue_user }
--%%type="com.fibaro.binarySwitch"

--FILE:lib/fibaroExtra.lua,fibaroExtra;
fibaro.debugFlags.extendedErrors = true
local fmt = string.format
local url,app_key
local E = fibaro.event
local P = fibaro.post
local v2 = "1948086000"
local Resources = {}
local ResourcesType = {}
local ResourceMap = {}
local QAs = {}

local HueDeviceTypes = {
  ["Hue motion sensor"]      = {types={"SML001"},          maker="MotionMaker",  class=""},
  ["Hue color lamp"]         = {types={"LCA001","LCT015"}, maker="LightMaker",   class="ColorLampQA"},
  ["Hue ambiance lamp"]      = {types={"LTA001"},          maker="LightMaker",   class="DimLampQA"},
  ["Hue white lamp"]         = {types={"LWA001"},          maker="LightMaker",   class="DimLampQA"},
  ["Hue color candle"]       = {types={"LCT012"},          maker="LightMaker",   class="ColorLampQA"},
  ["Hue filament bulb"]      = {types={"LWO003"},          maker="LightMaker",   class="DimLampQA"},
  ["Hue dimmer switch"]      = {types={"RWL021"},          maker="SwitchMaker",  class="ButtonQA"},
  ["Hue wall switch module"] = {types={"RDM001"},          maker="SwitchMaker",  class="ButtonQA"},
  ["Hue smart plug"]         = {types={"LOM007"},          maker="PlugMaker",    class="ButtonQA"},
  ["Hue color spot"]         = {types={"LCG0012"},         maker="LightMaker",   class="ColorLampQA"},
  ["Philips hue"]            = {types={"LCG0012"},         maker="NopMaker",     class=""},
}

local TypeMap = {
  ['MotionSensor']           = 'com.fibaro.motionSensor',
  ['TempSensor']             = 'com.fibaro.temperatureSensor',
  ['LuxSensor']              = 'com.fibaro.lightSensor',
  ['OnOff lamp']             = 'com.fibaro.binarySwitch',
  ['Hue color lamp']         = 'com.fibaro.colorController',
  ['Hue ambiance lamp']      = 'com.fibaro.multilevelSwitch',
  ['Hue white lamp']         = 'com.fibaro.multilevelSwitch',
  ['Hue color candle']       = 'com.fibaro.colorController',
  ['Hue filament bulb']      = 'com.fibaro.multilevelSwitch',
  ['Hue dimmer switch']      = 'com.fibaro.remoteController',
  ['Hue wall switch module'] = 'com.fibaro.remoteController',
  ['Hue smart plug']         = 'com.fibaro.binarySwitch',
  ['Hue color spot']         = 'com.fibaro.colorController',
}

local function dumpQAs()
  for id,qa in pairs(QAs) do quickApp:debugf("%s %s",qa.id,qa.name) end
end

local function getServices(t,s)
  local res = {}
  for _,r in ipairs(s) do if r.rtype==t then res[r.rid]=true end end
  return res 
end

function notifier(m,d) 
  local self = { devices = {} }
  function self:update(data) for _,d in ipairs(self.devices) do d[m](d,data) end end
  function self:add(d) self.devices[#self.devices+1]=d end
  return self
end

local function sendHueCmd(api,data) 
  net.HTTPClient():request(url..api,{
      options = { method='PUT', data=data and json.encode(data), checkCertificate=false, headers={ ['hue-application-key'] = app_key }},
      success = function(res) P({type=event,success=json.decode(res.data)}) end,
      error = function(err) P({type=event,error=err})  end,
    })
end

local ID = 0
class 'HueDeviceQA'(QuickerAppChild)
function HueDeviceQA:__init(p,d,t)
  local bat = next(getServices("device_power",p.services or {}))
  local con = next(getServices("zigbee_connectivity",p.services or {}))
  ResourceMap[d.id]=self
  self.hueID = d.id
  local meta = d.metadata or d.owner and Resources[d.owner.rid].metadata or p.metadata
  ID=ID+1
  self.name = meta and meta.name or fmt("Device_%03d",ID)
  local typ = d.type ~= 'grouped_light' and d.type or p.type or ""
  self.name = typ.." "..self.name

  local ftype = TypeMap[t]
  local args =    {
    name = self.name,
    uid  = d.id,
    type = ftype,
    properties = {},
    interfaces = bat and {"battery"},
  }

  QuickerAppChild.__init(self,args)

  QAs[self.id] = self

  if bat then ResourceMap[bat] = ResourceMap[bat] or notifier('battery') ResourceMap[bat]:add(self) end
  if con then ResourceMap[con] = ResourceMap[con] or notifier('connectivity') ResourceMap[con]:add(self) end
end

function HueDeviceQA:__tostring()
  return fmt("QA:%s - %s",self.id,self.name)
end

function HueDeviceQA:update(ev)
  self:event(ev)
end

function HueDeviceQA:event(ev)
  quickApp:debugf("%s %s %s",self.name,self.id,ev)
end

function HueDeviceQA:battery(ev)
  quickApp:debugf("Battery %s %s %s",self.name,self.id,ev)
  self:updateProperty("batteryLevel",ev.power_state.battery_level)
end

function HueDeviceQA:connectivity(ev)
  quickApp:debugf("Connectivity %s %s %s",self.name,self.id,ev)
  self:updateProperty("dead",ev.status == 'connected')
end

class 'MotionSensorQA'(HueDeviceQA)
function MotionSensorQA:__init(p,d,t)
  HueDeviceQA.__init(self,p,d,t)
  self.value = d.motion.motion
  self:updateProperty('value',self.value)
end
function MotionSensorQA:event(ev)
  self.value = ev.motion.motion
  self:updateProperty('value',self.value)
  quickApp:debugf("Motion %s %s %s",self.id,self.name,ev.motion.motion)
end

class 'TempSensorQA'(HueDeviceQA)
function TempSensorQA:__init(p,d,t)
  HueDeviceQA.__init(self,p,d,t)
  self.value = d.temperature.temperature
  self:updateProperty('value',self.value)
end
function TempSensorQA:event(ev)
  self.value = ev.temperature.temperature
  quickApp:debugf("Temp %s %s %s",self.id,self.name,ev.temperature.temperature)
end

class 'LuxSensorQA'(HueDeviceQA)
function LuxSensorQA:__init(p,d,t)
  HueDeviceQA.__init(self,p,d,t)
  self.value = d.light.light_level
  self:updateProperty('value',self.value)
end
function LuxSensorQA:event(ev)
  self.value = math.floor(0.5+math.pow(10, (ev.light.light_level - 1) / 10000))
  quickApp:debugf("Lux %s %s %s",self.id,self.name,self.value)
end

class 'ButtonQA'(HueDeviceQA)
function ButtonQA:__init(d,buttons,t)
  HueDeviceQA.__init(self,d,d,t)
  self.buttons = buttons
  for id,_ in pairs(buttons) do ResourceMap[id]=self end
end
function ButtonQA:event(ev)
  quickApp:debugf("Button %s %s %s %s",self.id,self.name,self.buttons[ev.id],ev.button.last_event)
  local fevents = { ['initial_press']='Pressed',['repeat']='HeldDown',['short_release']='Released',['long_release']='Released' }
  local data = {
    type =  "centralSceneEvent",
    source = self.id,
    data = { keyAttribute = fevents[ev.button.last_event], keyId = self.buttons[ev.id] }
  }
  local a,b = api.post("/plugins/publishEvent", data)
end

class 'LampQA'(HueDeviceQA)
function LampQA:__init(p,d,t)
  HueDeviceQA.__init(self,p,d,t)
  self.on = d.on.on or false
  self.value = d.dimming and d.dimming.brightness or self.on and 99 or 0
end
function LampQA:event(ev)
  if ev.dimming then self.value = round(ev.dimming.brightness) end
  if ev.on then self.on = ev.on.on end
  quickApp:debugf("Light %s %s value:%s, on:%s",self.id,self.name,self.value,self.on)
end
function LampQA:turnOn()
  self:updateProperty("value",true)
  sendHueCmd("/clip/v2/resource/light/"..self.hueID,{on = {on = true }})
end
function LampQA:turnOff()
  self:updateProperty("value",false)
  sendHueCmd("/clip/v2/resource/light/"..self.hueID,{on = {on = false }})
end

class 'ColorLampQA'(LampQA)
function ColorLampQA:__init(p,d,t)
  LampQA.__init(self,p,d,t)
end

class 'DimLampQA'(LampQA)
function DimLampQA:__init(p,d,t)
  LampQA.__init(self,p,d,t)
end

class 'WhiteLampQA'(LampQA)
function WhiteLampQA:__init(p,d,t)
  LampQA.__init(self,p,d,t)
end

local DeviceMakers = {}

function DeviceMakers.MotionMaker(d,pn)
  local motionID = next(getServices("motion",d.services))
  local temperatureID = next(getServices("temperature",d.services))
  local light_levelID = next(getServices("light_level",d.services))

  MotionSensorQA(d,Resources[motionID],"MotionSensor")
  TempSensorQA(d,Resources[temperatureID],"TempSensor")
  LuxSensorQA(d,Resources[light_levelID],"LuxSensor")
end

function DeviceMakers.LightMaker(d,pn)
  local lightID = next(getServices("light",d.services))
  ColorLampQA(d,Resources[lightID],pn)
end

function DeviceMakers.SwitchMaker(d,pn)
  local buttonsIDs = getServices("button",d.services)
  local buttons = {}
  for id,_ in pairs(buttonsIDs) do
    buttons[id]=Resources[id].metadata.control_id
  end
  d.type="switch"
  ButtonQA(d,buttons,pn) 
end

function DeviceMakers.PlugMaker(d,pn)
  local lightID = next(getServices("light",d.services))
  ColorLampQA(d,Resources[lightID],pn)
end

function DeviceMakers.NopMaker(_,_) end

local function makeDevice(d)
  local p = d.product_data
  if HueDeviceTypes[p.product_name] then 
    DeviceMakers[HueDeviceTypes[p.product_name].maker](d,p.product_name)
  else
    quickApp:warningf("Unknown Hue type, %s %s",p.product_name,d.metadata and d.metadata.name or "")
  end
end

local function makeGroup(d)
  local lightID = next(getServices("grouped_light",d.services))
  LampQA(d,Resources[lightID],"OnOff lamp")
end

local function call(api,event) 
  net.HTTPClient():request(url..api,{
      options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = app_key }},
      success = function(res) P({type=event,success=json.decode(res.data)}) end,
      error = function(err) P({type=event,error=err})  end,
    })
end

E({type='START'},function() call("/api/config",'HUB_VERSION') end)

E({type='HUB_VERSION',success='$res'},function(env)
    if env.p.res.swversion >= v2 then
      quickApp:debugf("V2 api available (%s)",env.p.res.swversion)
    end
    call("/clip/v2/resource",'GET_RESOURCE')
  end)

E({type='HUB_VERSION',error='$err'},function(env)
    quickApp:errorf("Connections error from Hub: %s",env.p.err)
  end)

E({type='GET_RESOURCE',success='$res'},function(env)
    for _,d in ipairs(env.p.res.data or {}) do
      --quickApp:debugf("%s %s %s",d.type,d.metadata and d.metadata.name,d.id)
      Resources[d.id]=d
      ResourcesType[d.type] = ResourcesType[d.type] or {}
      ResourcesType[d.type][d.id]=d
    end
    for _,d in pairs(ResourcesType.device or {}) do makeDevice(d) end
    for _,d in pairs(ResourcesType.room or {})   do makeGroup(d) end
    for _,d in pairs(ResourcesType.zone or {})   do makeGroup(d) end
    dumpQAs()
  end)

E({type='GET_DEVICES',error='$err'},function(env) quickApp:error(env.p.err) end)

local function fetchEvents()
  local getw
  local eurl = url.."/eventstream/clip/v2"
  local args = { options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = app_key }}}
  function args.success(res)
    local data = json.decode(res.data)
    for _,e in ipairs(data) do
      if e.type=='update' then
        for _,e in ipairs(e.data) do
          if ResourceMap[e.id] then 
            ResourceMap[e.id]:update(e)
          else
            quickApp:warningf("Unknow resource type:%s",e)
          end
        end
      else
        quickApp:debugf("New event type:%s",e.type)
        quickApp:debugf("%s",json.encode(e))
      end
    end
    getw()
  end
  function args.error(err) if err~="timeout" then quickApp:errorf("/eventstream: %s",err) end getw() end
  function getw() net.HTTPClient():request(eurl,args) end
  setTimeout(getw,0)
end

function QuickApp:onInit()
  url = self:getVariable("Hue_IP")
  app_key = self:getVariable("Hue_User")
  url = fmt("https://%s:443",url)
  self:loadQuickerChildren()
  self:post({type='START'})
  fetchEvents()
end

