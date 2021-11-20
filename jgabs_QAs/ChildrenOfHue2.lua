-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDeviceQA MotionSensorQA TempSensorQA LuxSensorQA ButtonQA
-- luacheck: globals ignore LampQA ColorLampQA DimLampQA WhiteLampQA 

_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  copas=true,
  debug = { onAction=true, http=false, UIEevent=true },
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
--services: {rid="...", rtype="button"}
  ["Hue color spot"]         = {types={"LCG0012"},         maker="LightMaker",   class="ColorLampQA"},
  ["Philips hue"]            = {types={"LCG0012"},         maker="NopMaker",     class=""},
}

local ID = 33

local function getServices(t,s)
  local res = {}
  for _,r in ipairs(s) do if r.rtype==t then res[r.rid]=true end end
  return res 
end

function notifier(m,d) 
  local self = { devices = {} }
  function self:change(data) for _,d in ipairs(self.devices) do d[m](d,data) end end
  function self:add(d) self.devices[#self.devices+1]=d end
  return self
end

class 'HueDeviceQA'()
function HueDeviceQA:__init(p,d)
  local bat = next(getServices("device_power",p.services or {}))
  local con = next(getServices("zigbee_connectivity",p.services or {}))
  ResourceMap[d.id]=self
  self.bat = bat
  self.id = ID; ID=ID+1
  self.name = d.metadata and d.metadata.name
  if self.name == nil then
    if d.owner == nil then 
      a=0
    end
    self.name = self.name or Resources[d.owner.rid].metadata.name
  end
  if bat then ResourceMap[bat] = ResourceMap[bat] or notifier('battery') ResourceMap[bat]:add(self) end
  if bat then ResourceMap[con] = ResourceMap[con] or notifier('connectivity') ResourceMap[con]:add(self) end
end

function HueDeviceQA:update(ev)
  self:event(ev)
end

function HueDeviceQA:event(ev)
  quickApp:debugf("%s %s %s",self.name,self.id,ev)
end

function HueDeviceQA:battery(ev)
  quickApp:debugf("Battery %s %s %s",self.name,self.id,ev)
end

function HueDeviceQA:connectivity(ev)
  quickApp:debugf("Connectivity %s %s %s",self.name,self.id,ev)
end

class 'MotionSensorQA'(HueDeviceQA)
function MotionSensorQA:__init(p,d)
  HueDeviceQA.__init(self,p,d)
  self.value = false
end
function MotionSensorQA:event(ev)
  self.value = ev.motion.motion
  quickApp:debugf("Motion %s %s %s",self.id,self.name,ev.motion.motion)
end

class 'TempSensorQA'(HueDeviceQA)
function TempSensorQA:__init(p,d)
  HueDeviceQA.__init(self,p,d)
end
function TempSensorQA:event(ev)
  self.value = ev.temperature.temperature
  quickApp:debugf("Temp %s %s %s",self.id,self.name,ev.temperature.temperature)
end

class 'LuxSensorQA'(HueDeviceQA)
function LuxSensorQA:__init(p,d)
  HueDeviceQA.__init(self,p,d)
end
function LuxSensorQA:event(ev)
  quickApp:debugf("Lux %s %s %s",self.id,self.name,ev.light.light_level)
end

class 'ButtonQA'(HueDeviceQA)
function ButtonQA:__init(d,buttons)
  HueDeviceQA.__init(self,d,d)
  self.buttons = buttons
  for id,_ in pairs(buttons) do ResourceMap[id]=self end
end
function ButtonQA:event(ev)
  quickApp:debugf("Button %s %s %s %s",self.id,self.name,self.buttons[ev.id],ev.button.last_event)
end

class 'LampQA'(HueDeviceQA)
function LampQA:__init(p,d)
  HueDeviceQA.__init(self,p,d)
  self.value = 0
  self.on = false
end
function LampQA:event(ev)
  if ev.dimming then self.value = ev.dimming.brightness end
  if ev.on then self.on = ev.on.on end
  quickApp:debugf("Light %s %s value:%s, on:%s",self.id,self.name,self.value,self.on)
  quickApp:debugf("=>%s",ev)
end

class 'ColorLampQA'(LampQA)
function ColorLampQA:__init(p,d)
  LampQA.__init(self,p,d)
end

class 'DimLampQA'(LampQA)
function DimLampQA:__init(p,d)
  LampQA.__init(self,p,d)
end

class 'WhiteLampQA'(LampQA)
function WhiteLampQA:__init(d)
  LampQA.__init(self,p,d)
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
  ColorLampQA(d,Resources[lightID])
end

function DeviceMakers.SwitchMaker(d)
  local buttonsIDs = getServices("button",d.services)
  local buttons = {}
  for id,_ in pairs(buttonsIDs) do
    buttons[id]=Resources[id].metadata.control_id
  end
  ButtonQA(d,buttons) 
end

function DeviceMakers.PlugMaker(d)
  local lightID = next(getServices("light",d.services))
  ColorLampQA(d,Resources[lightID])
end

function DeviceMakers.NopMaker(d) end

local function makeDevice(d)
  local p = d.product_data
  if HueDeviceTypes[p.product_name] then 
    DeviceMakers[HueDeviceTypes[p.product_name].maker](d)
  else
    quickApp:warningf("Unknown Hue type, %s %s",p.product_name,d.metadata and d.metadata.name or "")
  end
end

local function makeGroup(d)
  LampQA(d,d)
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
      quickApp:debugf("%s %s %s",d.type,d.metadata and d.metadata.name,d.id)
      Resources[d.id]=d
      ResourcesType[d.type] = ResourcesType[d.type] or {}
      ResourcesType[d.type][d.id]=d
    end
    for _,d in pairs(ResourcesType.device or {}) do makeDevice(d) end
    for _,d in pairs(ResourcesType.grouped_light or {}) do makeGroup(d) end
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

  self:post({type='START'})
  fetchEvents()
end

