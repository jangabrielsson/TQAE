-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator
-- luacheck: globals ignore HueDevice ZLLSwitch ZLLTemperature ZLLLightLevel BinarySensor BinarySwitch 
-- luacheck: globals ignore Dimmable_light LightGroup Color_light ZLLPresence Extended_color_light

_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
}

--%%name="ChildrenOfHue"
-- %%proxy=true
--%%type="com.fibaro.deviceController"
--%%quickVars = {["Hue_IP"]=EM.cfg.Hue_IP,["Hue_User"]=EM.cfg.Hue_user }
--%%u1={label="status", text=""}
--%%u2={{button='allLightsOff', text='Lights On'},{button='allLightsOff', text='Lights Off'}}
--%%u3={{button='installLights', text='Install Lights'},{button='removeLights', text='Remove Lights'}}
--%%u4={{button='installSensors', text='Install Sensors'},{button='removeSensors', text='Remove Sensors'}}
--%%u5={{button='installGroups', text='Install Groups'},{button='removeGroups', text='Remove Groups'}}
--%%u6={{button='installCLIPS', text='Install CLIP sensors'},{button='removeCLIPS', text='Remove CLIP sensors'}}
--%%u7={{button='debug', text='Debug On'},{button='list', text="List"}}
--%%u8={button="connect", text='Authenticate'}
--%%u9={label="message", text=""}
--%%u10={label="pollingTime", text="Polling time: 1000ms"}
--%%u11={slider="pollingSlider", onChanged="polling"}
--%%u12={label="pollingFactor", text="Poll lights slower: 1x"}
--%%u13={{button="b1x", text="1x", onReleased='pollFactor'},{button="b2x", text="2x", onReleased='pollFactor'},{button="b3x", text="3x", onReleased='pollFactor'},{button="b4x", text="4x", onReleased='pollFactor'}}
--%%u14={button="patch", text='patchQA',onReleased="patchQA"}

--FILE:Libs/fibaroExtra.lua,fibaroExtra;
----------- Code -----------------------------------------------------------
local _version = 1.19
local serial = "UPD896661234567893"

local HUE2DEV = {lights={},sensors={}, scenes={}, groups={}} -- -> dev class
local SCENES = {}
local HUETIMEOUT,Hue = nil,nil
local pollingTime = 1
local pollingFactor = 1
local POLLALL = 0
local DIMTIME,DIMSTEP,DIM2OFF,DIMOLD=0,0,true,false
local format = string.format
local function Debug(flag,...) if flag then quickApp:debugf(...) end end
local DEBUG
local debugFlags = { hue = true, changes=true, children=true, app=true  } 

local CLIPSENSORS = {
--  {name="MySwitch1",type='CLIPGenericFlag',version="2"},
--  {name="MyPresence",type='CLIPPresence',version="1"},  
--  {name="MyDoor",type='CLIPOpenClose',version="1"},  
}

--------------------------------------------------------
-- 'com.fibaro.philipsHueLight'
local HUE_TYPE_MAP = {
  ['Extended color light']    = {ftype='com.fibaro.philipsHueLight',  class='Extended_color_light'},
  ['Color light']             = {ftype='com.fibaro.colorController',  class='Color_light'},
  ['Color temperature light'] = {ftype='com.fibaro.multilevelSwitch', class='Dimmable_light'},
  ['Dimmable light']          = {ftype='com.fibaro.multilevelSwitch', class='Dimmable_light'},
  ['ZLLLightLevel']           = {ftype='com.fibaro.lightSensor',      class='ZLLLightLevel'},
  ['ZLLSwitch']               = {ftype='com.fibaro.remoteController', class='ZLLSwitch'},
  ['ZLLPresence']             = {ftype='com.fibaro.motionSensor',     class='ZLLPresence'},
  ['ZLLTemperature']          = {ftype='com.fibaro.temperatureSensor',class='ZLLTemperature'},

  ['Room']                    = {ftype='com.fibaro.multilevelSwitch', class='LightGroup'},
  ['Zone']                    = {ftype='com.fibaro.multilevelSwitch', class='LightGroup'},
  ['CLIPGenericFlag']         = {ftype='com.fibaro.binarySwitch',     class='BinarySwitch'},
  ['CLIPPresence']            = {ftype='com.fibaro.motionSensor',     class='ZLLPresence'},
  ['CLIPTemperature']         = {ftype='com.fibaro.temperatureSensor',class='ZLLTemperature'},  
  ['CLIPPressure']            = {ftype='com.fibaro.binarySwitch',     class='BinarySwitch'},
  ['CLIPHumidity']            = {ftype='com.fibaro.humiditySensor',   class='Humidity'},
  ['CLIPOpenClose']           = {ftype='com.fibaro.binarySensor',     class='BinarySensor'},
}
HUE_TYPE_MAP["ZLLSwitch"].props = function() 
  return {
    initialProperties = {
      batteryLevel = 100,
      centralSceneSupport = {   
        { keyAttributes = {"Pressed","Released","HeldDown","Pressed2","Pressed3"},keyId = 1 },
        { keyAttributes = {"Pressed","Released","HeldDown","Pressed2","Pressed3"},keyId = 2 },
        { keyAttributes = {"Pressed","Released","HeldDown","Pressed2","Pressed3"},keyId = 3 },
        { keyAttributes = {"Pressed","Released","HeldDown","Pressed2","Pressed3"},keyId = 4 },
        { keyAttributes = {"Pressed","Released","HeldDown","Pressed2","Pressed3"},keyId = 5 },
        { keyAttributes = {"Pressed","Released","HeldDown","Pressed2","Pressed3"},keyId = 6 },
      }
    },
    initialInterfaces = { 'zwaveCentralScene', 'battery' },
  }
end
HUE_TYPE_MAP["ZLLTemperature"].props = function() 
  return {
    initialProperties = { batteryLevel = 100, },
    initialInterfaces = { 'battery'},
  }
end
HUE_TYPE_MAP["ZLLPresence"].props = function()
  return {
    initialProperties = { batteryLevel = 100, },
    initialInterfaces = { 'battery'},
  }
end
HUE_TYPE_MAP["ZLLLightLevel"].props = function()
  return {
    initialProperties = { batteryLevel = 100, },
    initialInterfaces = { 'battery'},
  }
end
HUE_TYPE_MAP["Extended color light"].props = function() return {} end
HUE_TYPE_MAP["Color temperature light"].props = function() return {} end
HUE_TYPE_MAP["Color light"].props = function() return {} end
HUE_TYPE_MAP["Dimmable light"].props = function() return {} end
HUE_TYPE_MAP["Room"].props = function() return {} end
HUE_TYPE_MAP["CLIPPresence"].props = function() return {} end
HUE_TYPE_MAP["CLIPGenericFlag"].props = function() return {} end
HUE_TYPE_MAP["CLIPOpenClose"].props = function() return {} end
HUE_TYPE_MAP["CLIPTemperature"].props = function() return {} end
HUE_TYPE_MAP["CLIPHumidity"].props = function() return {} end
HUE_TYPE_MAP["CLIPPressure"].props = function() return {} end

local CLIPSSTATE={
  ["CLIPPresence"] = {presence = false},
  ["CLIPSwitch"] = {buttonevent = 1000},
  ["CLIPOpenClose"] = {open = false},
  ["CLIPTemperature"] = {temperture = 0},
  ["CLIPHumidity"] = {humidity = 0},
  ["CLIPLightlevel"] = {lightlevel = 0, dark=false, daylight=false},
  ["CLIPGenericStatus"] = {status = 0},
  ["CLIPGenericFlag"] = {flag = false},
}

local function checksum(str)
  local v = 0
  for i=1,#str do v=v+str:byte(i) end
  return 93847148 + 3*v % 1000000
end

local function installCLIP(clip)
  local payload = {
    state = CLIPSSTATE[clip.type],
    name=clip.name,
    modelid = "HC3CLIP",
    swversion="1.0",
    type =  clip.type,
    uniqueid=tostring(checksum(clip.name..clip.type..(clip.version or ""))),
    manufacturername = "ChildrenOfHue"
  }
  Hue.request("/sensors","POST",payload,
    function(status)
      if status.status==200 then    -- If success, add id to clip def
        local v = json.decode(status.data)
        local id = v[1].success.id
        quickApp:debug(format("Hue bridge: CLIP %s, type:%s (installed)",clip.name,clip.type))
        clip.id = id
      end
    end)
end

local function createColorConverter()
  local self = {}

  local function round(x) return math.floor(x+0.5) end

  function self.hsb2rgb(hue,saturation,brightness) --0-65535,0-255,0-255
    if saturation == 0 then return {r=brightness, g=brightness, b=brightness} end
    hue        = 360*hue/65535
    saturation = saturation/254
    brightness = brightness/254

    -- the color wheel consists of 6 sectors. Figure out which sector you're in.
    local sectorPos = hue / 60.0
    local sectorNumber = math.floor(sectorPos)
    -- get the fractional part of the sector
    local fractionalSector = sectorPos - sectorNumber

    -- calculate values for the three axes of the color. 
    local p = brightness * (1.0 - saturation)
    local q = brightness * (1.0 - (saturation * fractionalSector))
    local t = brightness * (1.0 - (saturation * (1 - fractionalSector)))

    p,q,t,brightness=round(p*255),round(q*255),round(t*255),round(brightness*255)
    -- assign the fractional colors to r, g, and b based on the sector the angle is in.
    if sectorNumber==0 then return {r=brightness,g=t,b=p}
    elseif sectorNumber==1 then return {r=q,g=brightness,b=p}
    elseif sectorNumber==2 then return {r=p,g=brightness,b=t}
    elseif sectorNumber==3 then return {r=p,g=q,b=brightness}
    elseif sectorNumber==4 then return {r=t,g=p,b=brightness}
    elseif sectorNumber==5 then return {r=brightness,g=p,b=q} end
  end

  function self.rgb2hsb(r,g,b) -- 0-255,0-255,0-255
    local dRed   = r / 255;
    local dGreen = g / 255;
    local dBlue  = b / 255;

    local max = math.max(dRed, math.max(dGreen, dBlue));
    local min = math.min(dRed, math.min(dGreen, dBlue));

    local h = 0;
    if (max == dRed and dGreen >= dBlue) then
      h = 60 * (dGreen - dBlue) / (max - min);
    elseif (max == dRed and dGreen < dBlue) then
      h = 60 * (dGreen - dBlue) / (max - min) + 360;
    elseif (max == dGreen) then
      h = 60 * (dBlue - dRed) / (max - min) + 120;
    elseif (max == dBlue) then
      h = 60 * (dRed - dGreen) / (max - min) + 240;
    end

    local s = (max == 0) and 0.0 or (1.0 - (min / max))

    return math.floor(65535*h/360+0.5), math.floor(0.5+254*s), math.floor(0.5+254*max)
  end
  return self
end
local Color = createColorConverter()

local function createHue(interval) 
  local self,ip,user = {},"",""
  self.types   = {lights="Light",sensors="Sensor",groups="Group", scenes="Scene"}
  self.lastHue = {}

--------------------------- Main Event loop -------------------------
  local main,post -- forward declaration

  local HTTP= netSync.HTTPClient()

  local function callOrPost(h,v) if h then if type(h)=='function' then h(v) else h.value=v; post(h) end end end
  local function request(url,op,payload,succ,err)
    if  url ~= "" and url ~= "auth" then quickApp:debugf("URL:%s",url) end
    if url=="auth" then 
      url=format("http://%s:80/api",ip)
    else 
      url = format("http://%s:80/api/%s%s",ip,user,url) 
    end
    op,payload = op or "GET", payload and json.encode(payload) or ""
    HTTP:request(url,{
        options = {
          headers={['Accept']='application/json',['Content-Type']='application/json'},
          data = payload, timeout=HUETIMEOUT or 5000, method = op},
        error = function(status) callOrPost(err,status) end,
        success = function(status) callOrPost(succ,status) end,
      })
  end

  self.request = request

  local EVENTS={}

  function EVENTS.start(e)
    ip = quickApp.config.Hue_IP or ""
    user = quickApp.config.Hue_User or ""
    if not ip:match("%d+%.%d+%.%d+%.%d+") then post({type='unconfigured',msg="Please set IP_Hue variable"})
    elseif #user < 10 then post({type='unconfigured',msg="Please authenticate with Hue bridge"})
    else request("",'GET',nil,{type='init'},{type='configErr'}) end
  end

  function EVENTS.init(e)
    local data = json.decode(e.value.data)
    if data[1] and data[1].error then
      return post({type='configErr', value = data[1].error})
    end
    quickApp:setStatus("connected")
    quickApp:setMsg("Connection suceeded")
    quickApp:tracef("Hue connected to %s",quickApp.config.Hue_IP)
    post({type='checkChanges',value=e.value})
    post({type='installClips',value=data})
  end

  function EVENTS.pollAll(e)
    request("",'GET',nil,{type='checkChanges'},{type='errPoll'})
  end

  function EVENTS.pollSens(e)
    request("/sensors",'GET',nil,{type='checkChanges'},{type='errPoll'})
  end

  function EVENTS.checkChanges(e)
    local data = json.decode(e.value.data)
    local types = Hue.types
    if not data.sensors then self.lastHue.sensors=data; data = self.lastHue; types = {sensors="Sensor"} end
    SCENES = data.scenes or SCENES
    self.lastHue = data
    for p,_ in pairs(types) do
      for id,obj in pairs(HUE2DEV[p] or {}) do -- Loop over all our devices and see if they changed
--          if p=='sensors' and data[p][id].type=='Geofence' then --Could we support Hue geofence as a presence device?
--          end
        local stat,res = pcall(function()
            if not data[p][id] then -- Hue device disapeared - remove
              quickApp:debugf("Removed device %s",obj.id)
              quickApp:removeChildDevice(obj.id)
              HUE2DEV[p][tostring(id)]=nil   
            elseif obj:changed(data[p][id]) then
              obj:update(data[p][id].state)
            end
          end)
        if not stat then quickApp:errorf("Updating %s, %s - %s",id,obj,res) end
      end
    end
    POLLALL = POLLALL+1
    if POLLALL>=pollingFactor then -- Poll sensors every pollingTime, poll lights every pollingFactor...
      POLLALL = 0
      post({type='pollAll'},pollingTime*1000) 
    else
      post({type='pollSens'},pollingTime*1000) 
    end
  end

  function EVENTS.authOk(e)
    local d = json.decode(e.value.data)
    d=d[1]
    if d.error then
      quickApp:trace(d.error.description)
      quickApp:setMsg(d.error.description)
    elseif d.success then
      local user = d.success.username
      if user then
        quickApp:setVariable("Hue_User",user)
        quickApp.Hue_User=user
        quickApp:debug("Authentication suceeded")
        quickApp:setMsg("Authentication suceeded")
      end
    end
    quickApp.authenticating = false
  end

  function EVENTS.authErr(e)
    quickApp:error(e)
    quickApp:setMsg("Authentication failed")
    quickApp.authenticating = false
  end

  function EVENTS.errPoll(e)
    quickApp:error(e)
    post({type='pollAll'},3*pollingTime*1000)
  end

  function EVENTS.errMsg(e)
    quickApp:errorf(e)
  end

  function EVENTS.log(e)
    quickApp:debugf(e)
  end

  local unconf = 0
  function EVENTS.unconfigured(e)
    if unconf % 5 == 0 then 
      quickApp:setStatus("Unconfigured") 
      quickApp:setMsg(e.msg) 
    end
    unconf = unconf + 1
    post({type='start'},2000)
  end

  local conferr = 0
  function EVENTS.configErr(e)
    if conferr % 3 == 0 then 
      local msg = format("Error connecting to Hue at %s (%s)",e.ip,e.value)
      quickApp:setMsg(msg)
      quickApp:error(msg) 
    end
    conferr = conferr + 1
    post({type='start'},5000)
  end

  function EVENTS.installClips(e)
    local data = e.value
    local seen = {}

    local function check(uniqueid,id) 
      for _,d in ipairs(CLIPSENSORS) do 
        d.uniqueid = d.uniqueid or tostring(checksum(d.name..d.type..(d.version or "")))
        if d.uniqueid == uniqueid then d.exist=true; d.id=id; return true end 
      end 
      return false
    end

    local function pr(e) print(json.encode(e)) end

    for id,dev in pairs(data['sensors']) do
      if dev.modelid=="HC3CLIP" then
        if not check(dev.uniqueid,id) then
          quickApp:debugf("Removing old CLIP id:%s, name:%s, type:%s",id,dev.name,dev.type)
          Hue.request("/sensors/"..id,"DELETE",{},pr,pr)
        end
      end
    end
    for _,dev in ipairs(CLIPSENSORS) do 
      if not dev.exist then
        quickApp:debugf("Installing new CLIP name:%s, type:",dev.name,dev.type)
        installCLIP(dev)
      end
    end
  end

  function main(ev) if EVENTS[ev.type] then EVENTS[ev.type](ev) end end
  function post(ev,t) setTimeout(function() main(ev) end,t or 0) end

  self.post = post

  return self
end -- createHue

-------------------------------------------------------------------------------------------------------------
---  Children
-------------------------------------------------------------------------------------------------------------

local function installDevice(tp,id,d) -- This is where we create new children when we click "install" buttons
  if HUE2DEV[tp][id] then
    Debug(debugFlags.changes,"%s:%s-%s already installed",tp,id,d.name)
  elseif HUE_TYPE_MAP[d.type] then
    local propFun,dtypes = HUE_TYPE_MAP[d.type].props,HUE_TYPE_MAP[d.type]
    local props = propFun and propFun() or {}
    local dev = quickApp:createChild{
      name = d.name,
      type=dtypes.ftype,
      className = dtypes.class,
      quickVars = { hueType = tp, hueId = id },
      properties = props.initialProperties or {},
      interfaces = props.initialInterfaces or {},
    }
    dev.hueType = tp
    dev.hueId = id
    dev._PROPWARN = false
    HUE2DEV[tp][tostring(id)]=dev
    quickApp:debugf("Installed %s:%s-%s",tp,id,d.name)
  else
    Debug(debugFlags.changes,"Can't install %s:%s-%s",tp,id,d.name)
  end
end

--------------------------------------------------------------
---       Supported children
--------------------------------------------------------------
class 'HueDevice'(QuickAppChild)

function HueDevice:__init(device) 
  QuickAppChild.__init(self,device)
  self.hueType = self:getVariable("hueType")
  self.hueId = self:getVariable("hueId")
  self.hueClass = self:getVariable("className")
  self:trace(self.hueClass," inited, hueId:",self.hueId,", deviceId:",self.id)
  self.battery = 0
end

function HueDevice:changed(data)
  local state = data.state
  if data.config.battery ~= self.battery then 
    self:updateProperty("batteryLevel",data.config.battery or 100)
  end
  for k,v in pairs(self.hueKeys or {}) do if state[k]~=v then return true end end
  return false
end

function HueDevice:updateHue(state)
  local keys = self.hueKeys
  quickApp:updateHue(self.id,state or {on=self.isOn,hue=keys.hue,sat=keys.sat,bri=keys.bri},self._url)
end

function HueDevice:setHueParameters(payload)
  quickApp:updateHue(self.id,payload,self._url)
end

------------ ZLLSwitch -----------------------------------
class 'ZLLSwitch'(HueDevice)

function ZLLSwitch:__init(device) 
  HueDevice.__init(self,device)
  self.hueKeys = {buttonevent='<_>'}
end
function ZLLSwitch:setValue(prop,value)
  if prop~='value' then return end
  local key = math.floor(value/1000)
  local modifier = ({"Pressed","HeldDown","Released","Released"})[value % 1000 +1]
  self:tracef("Hue keypad ID:%s, Key:%s, Modifier:%s",self.id,key,modifier)
  self:updateProperty("value",value)
  local data = {
    type =  "centralSceneEvent",
    source = self.id,
    data = { keyAttribute = modifier, keyId = key }
  }
  local a,b = api.post("/plugins/publishEvent", data)
end
function ZLLSwitch:update(state)
  self.hueKeys.buttonevent=state.buttonevent
  self.value=state.buttonevent
  self:setValue("value",state.buttonevent)
end

------------ ZLLTemperature -----------------------------------
class 'ZLLTemperature'(HueDevice)

function ZLLTemperature:__init(device) 
  HueDevice.__init(self,device) 
  self.hueKeys = {temperature = '<_>'}
end
function ZLLTemperature:setValue(prop,value)
  if prop~='value' then return end
  self:updateProperty(prop,value)
end
function ZLLTemperature:update(state)
  self.hueKeys.temperature = state.temperature
  self.value = state.temperature/100
  self:updateProperty("value",self.value)
  self:tracef("Hue Tempsensor ID:%s, Value:%s",self.id,self.value)
end

------------ ZLLLightLevel -----------------------------------
class 'ZLLLightLevel'(HueDevice)

function ZLLLightLevel:__init(device) 
  HueDevice.__init(self,device)
  self.hueKeys = {lightlevel='<_>'}
end
function ZLLLightLevel:setValue(prop,value)
  if prop~='value' then return end
  self:updateProperty(prop,value)
end
function ZLLLightLevel:update(state)
  self.hueKeys.lightlevel = state.lightlevel
  self:setVariable("daylight",state.daylight)
  self:setVariable("dark",state.dark)
  self.value = math.pow(10, (state.lightlevel - 1) / 10000)
  self:tracef("Hue Lightsensor ID:%s, Value:%s",self.id,self.value)
  self:updateProperty("value",self.value)
end

------------ BinarySensor -----------------------------------
class 'BinarySensor'(HueDevice)

function BinarySensor:__init(device) 
  HueDevice.__init(self,device)  
  self.hueKeys={open='<_>'}
  self._url    = "/sensors/%s/state"
end
function BinarySensor:turnOn() self:updateProperty("value",true) self:updateHue({open=true}) end
function BinarySensor:turnOff() self:updateProperty("value",false) self:updateHue({open=false}) end
function BinarySensor:update(state)
  self.hueKeys.open = state.open
  self.value = state.open
  self:updateProperty("value",self.value)
  self:updateProperty("state",self.value)
  self:tracef("BinarySensor (Hue) ID:%s, Value:%s",self.id,self.value)
end

------------ BinarySwitch -----------------------------------
class 'BinarySwitch'(HueDevice)

function BinarySwitch:__init(device) 
  HueDevice.__init(self,device)  
  self.hueKeys={flag='<_>'}
  self._url    = "/sensors/%s/statw"
end
function BinarySwitch:turnOn() self:updateProperty("value",true) self:updateHue({flag=true}) end
function BinarySwitch:turnOff() self:updateProperty("value",false) self:updateHue({flag=false}) end
function BinarySwitch:update(state)
  self.hueKeys.flag = state.flag
  self.value = state.flag
  self:updateProperty("value",self.value)
  self:updateProperty("state",self.value)
  self:tracef("Flag ID:%s, Value:%s",self.id,self.value)
end

------------ ZLLPresence -----------------------------------
class 'ZLLPresence'(HueDevice)

function ZLLPresence:__init(device) 
  HueDevice.__init(self,device)  
  self.hueKeys={presence='<_>'}
end
function ZLLPresence:turnOn() self:updateProperty("value",true) self:updateProperty("state",true) end
function ZLLPresence:turnOff() self:updateProperty("value",false) self:updateProperty("state",false) end
function ZLLPresence:update(state)
  self.hueKeys.presence = state.presence
  self.value = state.presence
  self:updateProperty("value",self.value)
  self:updateProperty("state",self.value)
  self:tracef("Presence ID:%s, Value:%s",self.id,self.value)
end

------------ Extended color light -----------------------------------
class 'Extended_color_light'(HueDevice)

function Extended_color_light:__init(device) 
  HueDevice.__init(self,device)  
  self.hueKeys = {bri="", on="", sat="", hue="", reachable="",}
  self.isOn = false
  self.value = 0
  self:updateProperty("useEmbeddedView",false)
end
function Extended_color_light:setValue(value) -- 0-100
  if type(value)=='table' then
    self:updateHue(value) 
  else
    local keys = self.hueKeys
    self.value = value
    keys.bri   = math.ceil(value/100*254)
    if keys.bri > 0 then self.isOn=true end
    self:updateProperty("value",self.isOn==false and 0 or self.value)
    self:updateProperty("state",self.isOn)
    self:updateHue({bri=keys.bri,on=self.isOn}) 
  end
end
function Extended_color_light:setColor(r,g,b)
  local keys = self.hueKeys
  self:updateProperty("color", table.concat({r,g,b,self.value},",") )
  keys.hue,keys.sat,keys.bri=Color.rgb2hsb(r,g,b)
  self:updateHue() 
end
function Extended_color_light:setTemperature(t)
  t = math.floor(0.5 + 1000000 / t)
  self:updateHue({ct=t})
end
function Extended_color_light:changeHue(h) self:updateHue({hue=h}) end
function Extended_color_light:changeSaturation(s) self:updateHue({sat=s}) end
function Extended_color_light:changeBrightness(b) self:setValue(math.ceil(b/255*100)) end
function Extended_color_light:hueClicked(value) self:changeHue(value) end
function Extended_color_light:saturationClicked(value) self:changeSaturation(value) end
function Extended_color_light:brightnessClicked(value) self:changeBrightness(value) end
function Extended_color_light:hue(s) self:changeHue(s.values[1]) end
function Extended_color_light:saturation(s) self:changeSaturation(s.values[1]) end
function Extended_color_light:brightness(s) self:changeBrightness(s.values[1]) end
function Extended_color_light:onClicked() self:turnOn() end
function Extended_color_light:offClicked() self:turnOff() end
function Extended_color_light:turnOn()
  if not self.isOn then self.isOn=true; self:updateHue({on=true}) end 
end
function Extended_color_light:turnOff()
  if self.isOn then self.isOn=false; self:updateHue({on=false}) end
end
function Extended_color_light:toggle()
  if self.isOn then self:turnOff() else self:turnOn() end
end
local function _startLevelIncrease2(hue)
  hue:stopLevelChange()
  if not hue.isOn then hue:turnOn() end
  local  bri = hue.hueKeys.bri
  local function increase()
    bri = bri + DIMSTEP
    hue:debug("ID:",hue.id," Dim:",bri)
    if bri >= 255 then 
      bri = 255
      hue:changeBrightness(bri)
      hue:stopLevelChange()
    else hue:changeBrightness(bri) end
  end
  hue.interval = setInterval(increase, 1000)
end
local function _startLevelDecrease2(hue)
  hue:stopLevelChange()
  local bri = hue.hueKeys.bri 
  local function decrease()
    if not hue.isOn then hue:stopLevelChange(); return end
    bri = bri - DIMSTEP
    if bri <= 0 then 
      bri = 0
      hue:changeBrightness(bri)
      hue:turnOff()
      hue:stopLevelChange() 
    else hue:changeBrightness(bri) end
  end
  hue.interval = setInterval(decrease,1000)
end
local function _stopLevelChange2(hue) if hue.interval then clearInterval(hue.interval) hue.interval=nil end end
local function _startLevelIncrease(self)
  self:debug("DU");
  self.dimDir = 'UP'
  if not self.isOn then
    self.isOn = true
    self:updateProperty("value",true)
    self:updateProperty("state",true)
    self.value=1
    self:updateHue({bri=1,on=true})
    self.hueKeys.bri = 1
  end
  local t = (254-self.hueKeys.bri)/254*DIMTIME
  self:updateHue({bri=254,on=true,transitiontime=math.ceil(10*t)}) 
end
local function _startLevelDecrease(self)
  self:debug("DD");
  self.dimDir = 'DOWN'
  local t = (self.hueKeys.bri)/254*DIMTIME
  self:updateHue({bri=1,transitiontime=math.ceil(10*t)})
end
local function _stopLevelChange(self) 
  self:debug("DS");
  if DIM2OFF and self.dimDir == 'DOWN' and self.hueKeys.bri<2 then
    self:turnOff()
  else
    self:updateHue({bri_inc=0}) 
  end
end

local function _toggleDimNoStop(self)
  local dimDir = self.dimDir
  if dimDir == nil then dimDir='down' end
  if dimDir == 'up' then
    self:startLevelDecrease()
    dimDir = 'down'
  elseif dimDir == 'down' then
    self:startLevelIncrease()
    dimDir = 'up'
  end
  self.dimDir = dimDir
end

local function _toggleDimAndStop(self)
  local dimDir = self.dimDir
  if dimDir == nil then dimDir='up' end
  if dimDir == 'up' then
    self:stopLevelChange()
    dimDir = 'stopDown'
  elseif dimDir == 'down' then
    self:stopLevelChange()
    dimDir = 'stopUp'
  elseif dimDir == 'stopUp' then
    self:startLevelIncrease()
    dimDir = 'up'
  elseif dimDir == 'stopDown' then
    self:startLevelDecrease()
    dimDir = 'down'
  end
  self.dimDir = dimDir
end

local function _toggleDim(self,stop) if stop then _toggleDimAndStop(self) else _toggleDimNoStop(self) end end

function Extended_color_light:startLevelIncrease() _startLevelIncrease(self) end
function Extended_color_light:startLevelDecrease() _startLevelDecrease(self) end
function Extended_color_light:stopLevelChange() _stopLevelChange(self) end
function Extended_color_light:toggleDim(stop) _toggleDim(self,stop) end

function Extended_color_light:customSettings(settings) 
  if settings == nil then settings = self:getVariable("state") end
  if type(settings) ~= 'table' then return end
  self:setValue({startup={customsettings=settings}})
end

function Extended_color_light:update(state)
  self:setVariable("state",state)
  local keys = self.hueKeys
  for k,v in pairs(keys) do keys[k]=state[k] end
  self.isOn      = keys.on and keys.reachable
  self.value     = math.max(1,math.ceil(keys.bri/254*100))
  keys.bri       = state.bri
  keys.sat       = state.sat
  keys.hue       = state.hue
  --self:tracef("Bri:%s, Sat:%s, Hue:%s",keys.bri,keys.sa,keys.hue)
  local rgb      = Color.hsb2rgb(keys.hue,keys.sat,keys.bri)  --> {0-255,0-255,0-255}
  local values   = table.concat({rgb.r,rgb.g,rgb.b,self.value},",")
  self:updateProperty("color", values)
  self:updateProperty("hue", keys.hue)
  self:updateView("hue","value",tostring(keys.hue))
  self:updateProperty("saturation", keys.sat)
  self:updateView("saturation","value",tostring(keys.sat))
  self:updateProperty("brightness", keys.bri)
  self:updateView("brightness","value",tostring(keys.bri))
  self:updateProperty("state", self.isOn)
  self:updateProperty("on", self.isOn)
  self:updateProperty("reachable", keys.reachable)
  self:updateProperty("value",self.isOn==false and 0 or self.value)
end

------------ Dimmable light -----------------------------------
class 'Dimmable_light'(HueDevice)

function Dimmable_light:__init(device) 
  HueDevice.__init(self,device)  
  self.hueKeys = {bri="", on="", reachable="",}
  self.isOn    = false
  self.value   = 0
end
function Dimmable_light:setValue(value) -- 0-100
  self.dirty=true
  if type(value)=='table' then
    self:updateHue(value)
  else
    local keys = self.hueKeys
    self.value = value
    keys.bri   = math.ceil(value/100*254)
    if keys.bri > 0 then self.isOn=true end
    self:updateProperty("value",value)
    self:updateProperty("state",self.isOn)
    self:updateHue({bri=keys.bri,on=self.isOn})
  end
end
function Dimmable_light:turnOn()
  if not self.isOn then self.isOn=true; self.dirty=true self:updateHue({on=true}) end 
end
function Dimmable_light:turnOff()
  if self.isOn then self.isOn=false; self.dirty=true self:updateHue({on=false}) end
end
function Dimmable_light:changeBrightness(b) self:setValue(math.ceil(b/255*100)) self.dirty=true end
function Dimmable_light:brightness(s) self:changeBrightness(s.values[1]) end
function Dimmable_light:toggle()
  if self.isOn then self:turnOff() else self:turnOn() end
end
function Dimmable_light:setTemperature(t)
  self.dirty=true
  t = math.floor(0.5 + 1000000 / t)
  self:updateHue({ct=t})
end
if DIMOLD then
  function Dimmable_light:startLevelIncrease() _startLevelIncrease2(self) end
  function Dimmable_light:startLevelDecrease() _startLevelDecrease2(self) end
  function Dimmable_light:stopLevelChange() _stopLevelChange2(self) end
  function Dimmable_light:toggleDim(stop) _toggleDim(self,stop) end
else
  function Dimmable_light:startLevelIncrease() _startLevelIncrease(self) end
  function Dimmable_light:startLevelDecrease() _startLevelDecrease(self) end
  function Dimmable_light:stopLevelChange() _stopLevelChange(self) end
  function Dimmable_light:toggleDim(stop) _toggleDim(self,stop) end
end

function Dimmable_light:customSettings(settings) 
  if settings == nil then settings = self:getVariable("state") end
  if type(settings) ~= 'table' then return end
  self:setValue({startup={customsettings=settings}})
end

function Dimmable_light:update(state)
  self.dirty=nil
  self:setVariable("state",state)
  local keys     = self.hueKeys
  keys.on,keys.reachable,keys.bri = state.on,state.reachable,state.bri
  self.isOn      = state.on and state.reachable
  self.value     = math.max(1,math.ceil(state.bri/254*100))
  self:updateProperty("value",self.isOn==false and 0 or self.value)
  self:updateProperty("state",self.isOn)
end

------------ LightGroup -----------------------------------
class 'LightGroup'(HueDevice)
function LightGroup:__init(device) 
  HueDevice.__init(self,device)
  self.hueKeys = {bri="", on=""}
  self.isOn    = false
  self.value   = 0
  self._url    = "/groups/%s/action"
end
function LightGroup:turnOn()
  if not self.isOn then self.isOn=true; self.dirty = true self:updateHue({on=true}) end 
end
function LightGroup:turnOff()
  if self.isOn then self.isOn=false; self.dirty = true self:updateHue({on=false}) end
end
function LightGroup:setValue(value) 
  self.dirty = true
  if type(value) =='table' then self:updateHue(value)
  else 
    local keys = self.hueKeys
    self.value = value
    keys.bri   = math.ceil(value/100*254) 
    if keys.bri  > 0 then self.isOn = true end
    self:updateProperty("value",value)
    self:updateProperty("state",self.isOn)
    self:updateHue({bri=keys.bri,on=self.isOn})
  end
end
function LightGroup:changeBrightness(b) self.dirty = true self:setValue(math.ceil(b/255*100)) end
function LightGroup:brightness(s) self:changeBrightness(s.values[1]) end
function LightGroup:toggle()
  if self.isOn then self:turnOff() else self:turnOn() end
end
function LightGroup:setTemperature(t)
  self.dirty = true
  t = math.floor(0.5 + 1000000 / t)
  self:updateHue({ct=t})
end
function LightGroup:setScene(scene)
  for id,v in pairs(SCENES) do if id==scene or v.name==scene then self:setValue({scene=id}) return end end
end
function LightGroup:startLevelIncrease() _startLevelIncrease(self) end
function LightGroup:startLevelDecrease() _startLevelDecrease(self) end
function LightGroup:stopLevelChange() _stopLevelChange(self) end
function LightGroup:toggleDim(stop) _toggleDim(self,stop) end

function LightGroup:changed(data) self.hdata = data; return true end  
function LightGroup:compoundState(data)
  self:setVariable("state",data)
  local on,bri,n=true,0,0
  for _,id in ipairs(data.lights) do
    n=n+1
    local l = Hue.lastHue['lights'][id]
    bri = bri + l.state.bri
    on = on and (l.state.on and l.state.reachable)
  end
  return {on=on, bri=math.ceil(bri/(n> 0 and n or 1))}
end
function LightGroup:update(state)
  local nstate = self:compoundState(self.hdata)
  if self.isOn ~= nstate.on or self.hueKeys.bri ~= nstate.bri  or self.dirty then
    self.dirty = nil
    self.isOn        = nstate.on 
    self.hueKeys.bri = nstate.bri
    self.hueKeys.on  = nstate.on
    self.value = math.max(1,math.ceil(self.hueKeys.bri/254*100))
    self:updateProperty("value",self.isOn==false and 0 or self.value)
    self:updateProperty("state",self.isOn)
  end
end

--------------------------------------------------------
class 'Color_light'(HueDevice)

function Color_light:__init(device) 
  HueDevice.__init(self,device)  
  self.hueKeys = {bri="", on="", sat="", hue="", reachable="",}
  self.isOn = false
  self.value = 0
end
function Color_light:setValue(value) -- 0-100
  if type(value)=='table' then self:updateHue(value) return end
  local keys = self.hueKeys
  self.value = value
  keys.bri   = math.ceil(value/100*254)
  if keys.bri > 0 then self.isOn=true end
  self:updateProperty("value",self.isOn==false and 0 or self.value)
  self:updateProperty("state",self.isOn)
  self:updateHue({bri=keys.bri,on=self.isOn}) 
end
function Color_light:setColor(r,g,b)
  local hue,sat,bri=Color.rgb2hsb(r,g,b)
  self:updateHue({hue=hue,sat=sat}) 
end
function Color_light:turnOn()
  if not self.isOn then self.isOn=true;  self:updateHue({on=true}) end 
end
function Color_light:turnOff()
  if self.isOn then self.isOn=false; self:updateHue({on=false}) end
end
function Color_light:setTemperature(t)
  t = math.floor(0.5 + 1000000 / t)
  self:updateHue({ct=t})
end
function Color_light:changeBrightness(b) self:setValue(math.ceil(b/254*100)) end
function Color_light:brightness(s) self:changeBrightness(s.values[1]) end
function Color_light:startLevelIncrease() _startLevelIncrease(self) end
function Color_light:startLevelDecrease() _startLevelDecrease(self) end
function Color_light:stopLevelChange() _stopLevelChange(self) end
function Color_light:toggleDim(stop) _toggleDim(self,stop) end

function Color_light:toggle()
  if self.isOn then self:turnOff() else self:turnOn() end
end
function Color_light:update(state)
  self:setVariable("state",state)
  local keys = self.hueKeys
  for k,v in pairs(keys) do keys[k]=state[k] end
  self.isOn      = keys.on and keys.reachable
  self.value     = math.max(1,math.ceil(keys.bri/254*100))
  local rgb      = Color.hsb2rgb(keys.hue,keys.sat,keys.bri)  --> {0-255,0-255,0-255}
  local values   = table.concat({rgb.r,rgb.g,rgb.b,self.value},",")
  self:updateProperty("color", values)
  self:updateProperty("state", self.isOn)
  self:updateProperty("value",self.isOn==false and 0 or self.value)
end

--------------------------------------------------------
----------------- UI buttons for controller device
--------------------------------------------------------
function QuickApp:listClicked() 
  for p,pn in pairs(Hue.types) do
    for id,obj in pairs(Hue.lastHue[p]) do
      self:debugf("%s id:%s, name:%s, type:%s",pn,id,obj.name,obj.type)
    end
  end
end

function QuickApp:debugClicked() 
  DEBUG=not DEBUG 
  quickApp:updateView("debug","text",DEBUG and "Debug On" or "Debug Off")
end

function QuickApp:polling(ev)
  pollingTime = (ev.values[1] // 25+1)
  self:setView("pollingTime","text","Polling time: %ss",pollingTime)
  self:setVariable("pollingTime",pollingTime)
end

function QuickApp:pollFactor(ev)
  pollingFactor = tonumber(ev.elementName:sub(2,2)) or 1
  self:setView("pollingFactor","text","Poll lights slower: %sx",pollingFactor)
  self:setVariable("pollingFactor",pollingFactor)
end

function QuickApp:connectClicked()
  if self.authenticating then
    self:debug("Authenticating")
    return
  end
  self.authenticating = true
  Hue.request("auth","POST",{devicetype = 'COH#C3'},{type='authOk'},{type='authErr'}) 
end

local function installDev(tp,filter)
  for id,dev in pairs(Hue.lastHue[tp] or {}) do
    if filter(dev,id) then installDevice(tp,id,dev) end
  end
end

local function removeDev(tp,filter) 
  for id,dev in pairs(HUE2DEV[tp] or {}) do
    if filter(Hue.lastHue[tp][id]) then
      quickApp:debugf("Removed device %s",dev.id)
      quickApp:removeChildDevice(dev.id)
      HUE2DEV[tp][tostring(id)]=nil   
    end
  end
end

function QuickApp:installLightsClicked()  installDev('lights',function(d,id) 
    if hc3_emulator then return id=='4' or id=='21' or id =='19' else return true end
  end)  end
function QuickApp:installGroupsClicked()  installDev('groups',function(d,id) 
    if hc3_emulator then return id~='1' else return true end
  end)  end
function QuickApp:installSensorsClicked() installDev('sensors',function(d) return not d.type:match("^CLIP") end) end
function QuickApp:removeLightsClicked()   removeDev('lights',function() return true end)   end
function QuickApp:removeGroupsClicked()   removeDev('groups',function() return true end)   end
function QuickApp:removeSensorsClicked()  removeDev('sensors',function(d) return not d.type:match("^CLIP") end)  end

function QuickApp:allLightsOnClicked()  self:updateHue(0,{on=true},"/groups/%s/action/")  end
function QuickApp:allLightsOffClicked() self:updateHue(0,{on=false},"/groups/%s/action/")  end

function QuickApp:installCLIPSClicked()
  installDev('sensors',function(d) return d.type:match("^CLIP") and d.modelid=="HC3CLIP" end)
end
function QuickApp:removeCLIPSClicked()
  removeDev('sensors',function(d) return d.type:match("^CLIP") and d.modelid=="HC3CLIP" end) 
end

function QuickApp:setStatus(stat)
  self:updateView('status','text',format("ChildrenOfHue %s, (%s)",_version,stat))
end

function QuickApp:setMsg(msg)
  self:updateView('message','text',msg)
  setTimeout(function() self:updateView('message','text',"") end,5000)
end

--------------------------------------------------------
----------------- Hue commands
--------------------------------------------------------

function QuickApp:updateHue(id,payload,url) -- Called from Device Proxy
  if self.childDevices[id] or id == 0 then
    local d=self.childDevices[id]
    if id == 0 then d = {hueId=0} end
    url = url or "/lights/%s/state"
    Hue.request(format(url,d.hueId),"PUT",payload) 
  else self:warningf("Device %s not registered",id) end 
end

--------------------------------------------------------
local function setVersion(model,serial,version)
  local m = model..":"..serial.."/"..version
  if __fibaro_get_device_property(quickApp.id,'model') ~= m then
    quickApp:updateProperty('model',m) 
  end
end

----------------- onInit/Startup -----------------------

function QuickApp:onInit()
  setVersion("ChildrenOfHue",serial,_version)
  
  self:setStatus("start")

  if not self.config.pollingTime then
    self:setVariable("pollingTime",pollingTime)
  else
    pollingTime = tonumber(self.config.pollingTime)
  end
  if not self.config.pollingFactor then
    self:setVariable("pollingFactor",pollingFactor)
  else
    pollingFactor = tonumber(self.config.pollingFactor)
  end
  if not self.config.dimtime then
    DIMTIME = 10
  else
    DIMTIME = tonumber(self.config.dimtime)
  end
  if not self.config.dimstep then
    DIMSTEP = 14
  else
    DIMSTEP = tonumber(self.config.dimstep)
  end
  if self.config.dim2off and string.lower(tostring(self.config.dim2off))=='true' then
    DIM2OFF = true
  else
    DIM2OFF = false
  end
  DIMOLD = self.config.dimold

  self:updateView("pollingSlider","value",tostring(math.ceil(pollingTime/11*100)))
  self:setView("pollingTime","text","pollingTime","text","Polling time: %sms",pollingTime)
  self:setView("pollingFactor","text","Poll lights slower: %sx",pollingFactor) 

  Hue = createHue(pollingTime)
  Hue.post({type='start'}) 

  for id,child in pairs(self.childDevices) do
    HUE2DEV[child.hueType][tostring(child.hueId)]=child
    child._PROPWARN = false
  end

end