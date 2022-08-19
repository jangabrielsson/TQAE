-- luacheck: globals ignore QuickAppBase QuickApp QuickerAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDeviceQA MotionSensorQA TempSensorQA LuxSensorQA SwitchQA HueTable HUEv2Engine
-- luacheck: globals ignore LightOnOff LightDimmable LightTemperature LightColor

local VERSION = 0.1
local SERIAL = "UPD896781234551432" 
local Devices = {}
local debug = { class=true }
local function DEBUG(tag,str,...) if debug[tag] then print(string.format(str,...)) end end

local function classes() 
  class 'HueClass'(QuickerAppChild)
  function HueClass:__init(dev)
    local uid = dev.uid

    local interfaces = dev.interfaces or {}
    if dev.battery then interfaces[#interfaces+1]='battery' end
    local args =    {
      name = dev.name,
      className = dev.class,
      uid  = dev.uid,
      type = dev.type,
      quickVars = dev.quickVars,
      properties = dev.properties,
      interfaces = interfaces,
    }

    local ns,created = QuickerAppChild.__init(self,args)
    Devices[self.uid]=self
    return self,created
  end
  function HueClass:update(event)
    if event.power_state then
      self:updateProperty("batteryLevel",event.power_state.value.battery_level or 0)
    end
    if event.status then
      self:updateProperty("dead",event.status.value~='connected')
    end
  end

  local btnMap = {initial_press="Pressed",['repeat']="HeldDown",short_release="Released",long_release="Released"}
  class 'Switch'(HueClass)
  function Switch:__init(dev) HueClass.__init(self,dev) end
  function Switch:update(event)
    HueClass.update(self,event)
    if not event.button then return end
    local btn = event.button
    local key = btn.keyId
    local v = btn.value
    local modifier = btnMap[v]
    local data = {
      type =  "centralSceneEvent",
      source = self.id,
      data = { keyAttribute = modifier, keyId = key }
    }
    local a,b = api.post("/plugins/publishEvent", data)
    DEBUG("class","Button '%s':%s btn:%s = %s",self.name,self.id,key,modifier)
  end

  class 'Temperature'(HueClass)
  function Temperature:__init(dev) HueClass.__init(self,dev) end
  function Temperature:update(event)
        HueClass.update(self,event)
    if not event.temperature then return end
    local temp = event.temperature.value
    self:updateProperty("value",temp)
    DEBUG("class","Temperature '%s':%s = %s",self.name,self.id,temp)
  end

  class 'Lux'(HueClass)
  function Lux:__init(dev) HueClass.__init(self,dev) end
  function Lux:update(event)
        HueClass.update(self,event)
    if not event.light then return end
    local lux = event.light.value
    lux = math.pow(10, (lux - 1) / 10000)
    self:updateProperty("value",lux)
    DEBUG("class","Lux '%s':%s = %s",self.name,self.id,lux)
  end

  class 'Motion'(HueClass)
  function Motion:__init(dev) HueClass.__init(self,dev) end
  function Motion:update(event)
        HueClass.update(self,event)
    if not event.motion then return end
    local motion = event.motion.value
    self:updateProperty("value",motion)
    DEBUG("class","Motion '%s':%s = %s",self.name,self.id,motion)
  end
end

local function createDevice(className,typ,uid,battery,r,properties,interfaces)
  if not Devices[uid] then
    return _G[className]({name=r.name,type=typ,uid=uid,class=className,battery=battery,interfaces=interfaces,properties=properties})
  end
end

function QuickApp:hueInited()
  local function printf(...) print(string.format(...)) end 
  self:updateView("info","text","Connected to HueConnector:"..quickApp.hue.id)
  local subs = {}
  local map = self.hue.getRsrc("deviceMap") 
  for uid,r in pairs(map or {}) do
    local m = {} for _,p in ipairs(r.props) do m[p]=true end
    local ds = {}
    if m.button then
      local centralSceneSupport,interfaces  = {},{ 'zwaveCentralScene'}
      for i=1,r.buttons or 0 do 
        centralSceneSupport[#centralSceneSupport+1]={ keyAttributes = {"Pressed","Released","HeldDown"},keyId = i }
      end

      ds[#ds+1]=createDevice("Switch","com.fibaro.remoteController", "b"..uid,m.power_state,r,{centralSceneSupport=centralSceneSupport},interfaces)
    end
    if m.light then
      ds[#ds+1]=createDevice("Lux","com.fibaro.lightSensor", "l"..uid,m.power_state,r)
    end
    if m.temperature then
      ds[#ds+1]=createDevice("Temperature","com.fibaro.temperatureSensor","t"..uid,m.power_state,r)
    end
    if m.motion then
      ds[#ds+1]=createDevice("Motion","com.fibaro.motionSensor","m"..uid,m.power_state,r)
    end
    if next(ds) then
      Devices[uid]=function(event) for _,d in ipairs(ds) do d:update(event) end end
      subs[#subs+1]=uid
    end
  end
  if next(subs) then self.hue.subscribeTo(subs) end
end

function QuickApp:hueEvent(uid,event)
  self:debug("Event:",uid," ",json.encode(event))
  if Devices[uid] then Devices[uid](event) end
end


function QuickApp:onInit()
  self:debug(self.name, self.id)
  classes()
  self:setupUpHue()
end

