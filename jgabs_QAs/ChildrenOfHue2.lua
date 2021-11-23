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
--FILE:lib/colorComponents.lua,colorComponents;
--FILE:lib/colorConversion.lua,colorConversion;

fibaro.debugFlags.extendedErrors = true
fibaro.debugFlags.hue = true

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
  ["Hue motion sensor"]      = {types={"SML001"},          maker="MotionMaker"},
  ["Hue color lamp"]         = {types={"LCA001","LCT015"}, maker="LightMaker"},
  ["Hue ambiance lamp"]      = {types={"LTA001"},          maker="LightMaker"},
  ["Hue white lamp"]         = {types={"LWA001"},          maker="LightMaker"},
  ["Hue color candle"]       = {types={"LCT012"},          maker="LightMaker"},
  ["Hue filament bulb"]      = {types={"LWO003"},          maker="LightMaker"},
  ["Hue dimmer switch"]      = {types={"RWL021"},          maker="SwitchMaker"},
  ["Hue wall switch module"] = {types={"RDM001"},          maker="SwitchMaker"},
  ["Hue smart plug"]         = {types={"LOM007"},          maker="PlugMaker"},
  ["Hue color spot"]         = {types={"LCG0012"},         maker="LightMaker"},
  ["Philips hue"]            = {types={"LCG0012"},         maker="NopMaker"},
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
function HueDeviceQA:__init(p,d,ftype)
  local bat = next(getServices("device_power",p.services or {}))
  local con = next(getServices("zigbee_connectivity",p.services or {}))
  ResourceMap[d.id]=self
  self.hueID = d.id
  local meta = d.metadata or d.owner and Resources[d.owner.rid].metadata or p.metadata
  ID=ID+1
  self.name = meta and meta.name or fmt("Device_%03d",ID)
  local typ = d.type ~= 'grouped_light' and d.type or p.type or ""
  self.name = typ.." "..self.name

  local args =    {
    name = self.name,
    uid  = d.id,
    type = ftype,
    properties = {},
    interfaces = bat and {"battery"},
  }

  QuickerAppChild.__init(self,args)

  QAs[self.id] = self

  if bat then 
    ResourceMap[bat] = ResourceMap[bat] or notifier('battery') 
    ResourceMap[bat]:add(self)
    self:battery(Resources[bat])
  end
  if con then 
    ResourceMap[con] = ResourceMap[con] or notifier('connectivity') 
    ResourceMap[con]:add(self) 
    self:connectivity(Resources[con])
  end
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
  self:updateProperty("batteryLevel",ev.power_state.battery_level)
  quickApp:debugf("Battery %s %s %s",self.name,self.id,ev.power_state.battery_level)
end

function HueDeviceQA:connectivity(ev)
  self:updateProperty("dead",ev.status == 'connected')
  quickApp:debugf("Connectivity %s %s %s",self.name,self.id,ev.status)
end

class 'MotionSensorQA'(HueDeviceQA)
function MotionSensorQA:__init(p,d)
  HueDeviceQA.__init(self,p,d,"com.fibaro.motionSensor")
  self.value = d.motion.motion
  self:updateProperty('value',self.value)
end
function MotionSensorQA:event(ev)
  self.value = ev.motion.motion
  self:updateProperty('value',self.value)
  quickApp:debugf("Motion %s %s %s",self.id,self.name,ev.motion.motion)
end

class 'TempSensorQA'(HueDeviceQA)
function TempSensorQA:__init(p,d)
  HueDeviceQA.__init(self,p,d,"com.fibaro.temperatureSensor")
  self.value = d.temperature.temperature
  self:updateProperty('value',self.value)
end
function TempSensorQA:event(ev)
  self.value = ev.temperature.temperature
  quickApp:debugf("Temp %s %s %s",self.id,self.name,ev.temperature.temperature)
end

class 'LuxSensorQA'(HueDeviceQA)
function LuxSensorQA:__init(p,d)
  HueDeviceQA.__init(self,p,d,"com.fibaro.lightSensor")
  self.value = d.light.light_level
  self:updateProperty('value',self.value)
end
function LuxSensorQA:event(ev)
  self.value = math.floor(0.5+math.pow(10, (ev.light.light_level - 1) / 10000))
  quickApp:debugf("Lux %s %s %s",self.id,self.name,self.value)
end

class 'ButtonQA'(HueDeviceQA)
function ButtonQA:__init(d,buttons)
  HueDeviceQA.__init(self,d,d,'com.fibaro.remoteController')
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

class 'LightQA'(HueDeviceQA)
function LightQA:__init(p,d)
  local controls,t = {},'com.fibaro.binarySwitch'
  self.controls = controls
  controls.on = function(data)
    self.on = data.on
    self:updateProperty('value',data.on and 99 or 0)
  end
  if d.dimming then 
    t = 'com.fibaro.multilevelSwitch' 
    controls.dimming = function(data)
      self.bri = data.brightness
    end
  end
  if d.color_temperature then 
    t = 'com.fibaro.colorController' 
    self.mirek_schema = d.color_temperature.mirek_schema
    local mirmin = self.mirek_schema.mirek_minimum
    local mirmax = self.mirek_schema.mirek_maximum
    controls.color_temperature = function(data)
      if not data.mirek_valid then return end
      self.mirek = data.mirek
      self.temperature = (self.mirek-mirmin)/(mirmax-mirmin) -- %
    end
  end
  if d.color then 
    t = 'com.fibaro.colorController' 
    controls.color = function(data)
      local xy = data.xy
      self.rgb = fibaro.colorConverter.xyBri2rgb(xy.x,xy.y,self.bri)
    end
  end
  HueDeviceQA.__init(self,p,d,t)
  self.colorComponent = ColorComponents{
    parent = self,
    colorComponents = {
      warmWhite =  controls.color_temperature and 0 or nil,
      red =  controls.color and 0 or nil,
      green = controls.color and 0 or nil,
      blue = controls.color and 0 or nil,
    },
    dim_time   = 10000,  -- Time to do a full dim cycle, max to min, min to max
    dim_min    = 0,      -- Min value
    dim_max    = 99,     -- Max value
    dim_interv = 1000    -- Interval between dim steps
  }
  self:event(d)
end
function LightQA:event(ev)
  for _,h in ipairs({'on','dimming','color_temperature','color'}) do
    if ev[h] then self.controls[h](ev[h]) end
  end
  quickApp:debugf("Light %s %s on:%s, dim:%s, temp:%s rgb:%s, ",self.id,self.name,
    self.on,self.bri or "nil",self.temperature or "nil",self.rgb or "{}"
    )
end
function LightQA:turnOn()
  self:updateProperty("value",true)
  sendHueCmd("/clip/v2/resource/light/"..self.hueID,{on = {on = true }})
end
function LightQA:turnOff()
  self:updateProperty("value",false)
  sendHueCmd("/clip/v2/resource/light/"..self.hueID,{on = {on = false }})
end

local DeviceMakers = {}

function DeviceMakers.MotionMaker(d)
  local motionID = next(getServices("motion",d.services))
  local temperatureID = next(getServices("temperature",d.services))
  local light_levelID = next(getServices("light_level",d.services))

  MotionSensorQA(d,Resources[motionID])
  TempSensorQA(d,Resources[temperatureID])
  LuxSensorQA(d,Resources[light_levelID])
end

function DeviceMakers.LightMaker(d)
  local lightID = next(getServices("light",d.services))
  LightQA(d,Resources[lightID])
end

function DeviceMakers.SwitchMaker(d)
  local buttonsIDs = getServices("button",d.services)
  local buttons = {}
  for id,_ in pairs(buttonsIDs) do
    buttons[id]=Resources[id].metadata.control_id
  end
  d.type="switch"
  ButtonQA(d,buttons) 
end

function DeviceMakers.PlugMaker(d)
  local lightID = next(getServices("light",d.services))
  LightQA(d,Resources[lightID])
end

function DeviceMakers.NopMaker(_) end

local function makeDevice(d)
  local p = d.product_data
  if HueDeviceTypes[p.product_name] then 
    DeviceMakers[HueDeviceTypes[p.product_name].maker](d)
  else
    quickApp:warningf("Unknown Hue type, %s %s",p.product_name,d.metadata and d.metadata.name or "")
  end
end

local function makeGroup(d)
  local lightID = next(getServices("grouped_light",d.services))
  LightQA(d,Resources[lightID])
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

