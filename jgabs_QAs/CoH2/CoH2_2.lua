-- luacheck: globals ignore QuickAppBase QuickApp QuickerAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDeviceQA MotionSensorQA TempSensorQA LuxSensorQA SwitchQA HueTable HUEv2Engine
-- luacheck: globals ignore LightOnOff LightDimmable LightTemperature LightColor

local HUE
local DIMTIME,INTERVS=10,1
local function main()

  fibaro.debugFlags.extendedErrors = true
  fibaro.debugFlags.hue = true

  local fmt = string.format
  local UID2QA = {}

  local HueDeviceTypes = {
    ["Hue motion sensor"]      = {types={"SML001"},          class="MotionSensorQA"},
    ["Hue color lamp"]         = {types={"LCA001","LCT015"}, class="ColorLightQA"},
    ["Hue ambiance lamp"]      = {types={"LTA001"},          class="ColorLightQA"},
    ["Hue white lamp"]         = {types={"LWA001"},          class="ColorLightQA"},
    ["Hue color candle"]       = {types={"LCT012"},          class="ColorLightQA"},
    ["Hue filament bulb"]      = {types={"LWO003"},          class="ColorLightQA"},
    ["Hue dimmer switch"]      = {types={"RWL021"},          class="SwitchQA"},
    ["Hue wall switch module"] = {types={"RDM001"},          class="SwitchQA"},
    ["Hue smart plug"]         = {types={"LOM007"},          class="LightQA"},
    ["Hue color spot"]         = {types={"LCG0012"},         class="ColorLightQA"},
  }

  local function DEBUG(fm,...) print(fmt(fm,...)) end
  local function WARNING(fm,...) quickApp:warning(fmt(fm,...)) end

  local function dumpQAs()
    for id,qa in pairs(UID2QA) do quickApp:debugf("DeviceId:%s (%s) '%s' %s",qa.id,qa.uid,qa.name,qa.type) end
  end

  class 'HueDeviceQA'(QuickerAppChild)
  function HueDeviceQA:__init(info)
    self.uid,puid = info.uid,info.puid
    local d = HUE:getResource(puid or info.uid)

    function self:dev() 
      return HUE:getResource(puid or self.uid) 
    end
    function self:listen(prop,fun) self:dev():addListener(prop,fun) end
    function self:_call(m,...) return self:dev():call(m,...) end
    function self:_prop(prop) return self:dev().props[prop] end

    local bat = self:_prop('battery')
    info.name = info.name or d.rName

    local interfaces = info.interfaces or {}
    if bat then interfaces[#interfaces+1]='battery' end
    local args =    {
      name = info.name,
      uid  = info.uid,
      type = info.type,
      quickVars = info.quickVars,
      properties = info.properties,
      interfaces = interfaces,
    }

    _,created = QuickerAppChild.__init(self,args)
    UID2QA[info.uid] = self

    if bat then
      self:listen('battery',function(_,val) 
          self:updateProperty("batteryLevel",val)
          quickApp:debugf("Battery %s %s %s%%",self.name,self.id,val)
        end)
    end

    if self:_prop('connected')~=nil then 
      self:listen('connected',function(_,val) 
          self:updateProperty("dead",not val)
          quickApp:debugf("Connected %s %s %s",self.name,self.id,val)
        end)
    end
    return self,created
  end

  function HueDeviceQA:__tostring()
    return fmt("QA:%s - %s",self.id,self.name)
  end

  class 'MotionSensorQA'(HueDeviceQA)
  function MotionSensorQA:__init(info)
    info.type="com.fibaro.motionSensor"
    local _,created = HueDeviceQA.__init(self,info)
    self:listen("motion",function(_,value)
        self.value = value
        self:updateProperty('value',self.value)
        quickApp:debugf("Motion %s %s %s",self.id,self.name,self.value)
      end)
    if created then
      local temp = self:dev():getServices('temperature')[1]
      local lux = self:dev():getServices('light_level')[1]
      LuxSensorQA( {uid=lux.id, puid=self.uid})
      TempSensorQA({uid=temp.id,puid=self.uid})
    end
  end

  class 'TempSensorQA'(HueDeviceQA)
  function TempSensorQA:__init(info)
    info.type="com.fibaro.temperatureSensor"
    if not info.puid then
      local p = HUE:getResource(info.uid)
      info.puid = next(p.parents)
    end
    HueDeviceQA.__init(self,info)
    self:listen("temperature",function(_,value)
        self.value = value
        self:updateProperty('value',self.value)
        quickApp:debugf("Temp %s %s %.2fº",self.id,self.name,self.value)
      end)
  end

  class 'LuxSensorQA'(HueDeviceQA)
  function LuxSensorQA:__init(info)
    info.type='com.fibaro.lightSensor'
    if not info.puid then
      local p = HUE:getResource(info.uid)
      info.puid = next(p.parents)
    end
    HueDeviceQA.__init(self,info)
    self:listen("lux",function(_,value)
        self.value = value
        self:updateProperty('value',self.value)
        quickApp:debugf("Lux %s %s %s",self.id,self.name,self.value)
      end)
  end

  class 'SwitchQA'(HueDeviceQA)
  function SwitchQA:__init(info)
    info.type='com.fibaro.remoteController'
    local d = HUE:getResource(info.uid)

    local css = {}
    for _,s in ipairs(d.services or {}) do
      if s.rtype == 'button' then
        local b = HUE:getResource(s.rid)
        local id = b.metadata.control_id
        css[#css+1]={ keyAttributes = {"Pressed","Released","HeldDown","Pressed2","Pressed3"},keyId = id }
      end
    end

    info.properties = info.properties or {}
    info.properties.centralSceneSupport = css

    info.interfaces = info.interfaces or {}
    info.interfaces[#info.interfaces+1]='zwaveCentralScene'
    HueDeviceQA.__init(self,info)

    self:listen('button',function(_,val)
        quickApp:debugf("Button %s %s %s %s",self.id,self.name,val.id,val.value)
        local fevents = { ['initial_press']='Pressed',['repeat']='HeldDown',['short_release']='Released',['long_release']='Released' }
        local data = {
          type =  "centralSceneEvent",
          source = self.id,
          data = { keyAttribute = fevents[val.value], keyId = val.id }
        }
        local a,b = api.post("/plugins/publishEvent", data)
      end)
  end

  local function decorateLight(light)
    local d = light:dev()
    light.cfg = {}

    function light:turnOn() self:_call('turnOn') end
    function light:turnOff() self:_call('turnOff') end

    function light:setValue(value)
    end
    function light:setValue(value)
    end

    if light:_prop('brightness') then
      light.cfg.min_dim = d.dimming.min_dim_level or 1 
      function light:setBrightness(bri)
        self:_call("setBrightness",bri)
      end
      function light:getBrightness()
        return self:_prop("brightness")
      end
    end

    if light:_prop('temp') then
      light.cfg.min_mirek = d.color_temperature.mirek_schema.mirek_minimum
      light.cfg.max_mirek = d.color_temperature.mirek_schema.mirek_maximum 
      function light:setTemperature(t)
        DEBUG("setTemp(%s) H:%s",self.id,t)
        t = (t/254) * (self.cfg.max_mirek-self.cfg.min_mirek) + self.cfg.min_mirek
        self:_call("setTemperature",t)   -- mirek
      end
      function light:getTemperature() return self:_prop('temperature') end
      function light:temperature(t) self:setTemperature(t.values[1]) end -- 0..99 button handler
    end

    if light:_prop('color') then
      function light:setColor(color) self:_call('setColor',color) end
      function light:getColor() return self:_prop('color') end
      function light:setColorXY(x,y) return self:_call('setColorXY',x,y) end
      function light:getColorXY() return self:_prop('colorXY') end
      function light:setColorRGB(r,g,b) return self:_call('setColorRGB',r,g,b) end
      function light:getColorRGB() return self:_call('getColorRGB') end
    end

    light:listen('on',function(_,on)
        light:updateProperty('state',on)
        light.on = on
        DEBUG("Event on(%s) H:%s",light.id,light.on)
        light:updateProperty('value',light.on and (light.fib_bri or 99) or 0)
      end)

    light:listen('brightness',function(_,brightness)
        light.raw_bri = brightness
        local bri = math.floor(light.raw_bri + 0.5)
        light.fib_bri = math.max(light.cfg.min_dim or 1,bri)
        DEBUG("Event dim(%s) H:%s F:%s (%s)",light.id,light.raw_bri,light.fib_bri,light.on)
        light:updateProperty('value',light.on and light.fib_bri or 0) 
      end)

    light:listen('temp',function(_,temp)
        if not temp.mirek_valid then return end
        light.temp = temp.mirek
        local tempP = math.floor(254*(light.temp-light.cfg.min_mirek)/(light.cfg.max_mirek-light.cfg.min_mirek))
        DEBUG("Event mirek(%s) H:%s F:%s",light.id,temp.mirek,tempP)
        light:updateView('temperature',"value",tostring(tempP))
      end)

    light:listen('xy',function(_,value)
      end)

    function light:setValue(v) -- 0-99
      DEBUG("setValue(%s) F:%s",light.id,v)
      if v > 100 then v = 100 end
      if v == 0 then
        light:turnOff()
      else
        v = v < self.cfg.min_dim and self.cfg.min_dim or v
        if not light.on then light.fib_bri=v light:turnOn() end
        DEBUG("setValue(%s) H:%s",light.id,v)
        hueCall(self.url,{dimming={brightness=v}})
      end
    end

    function light:startLevelIncrease()
      DEBUG("startLevelIncrease")
      if self.ref then self.ref=clearTimeout(self.ref) end
      local dimValue = self.raw_bri
      if not self.on then
        self:turnOn()
        dimValue = 0
      end
      local tDelta = (100/(DIMTIME or 10))*(INTERVS or 0.5)
      local function loop()
        self.ref=nil
        dimValue = math.min(dimValue+tDelta,100)
        self:setValue(dimValue)
        if dimValue < 100 then self.ref=setTimeout(loop,1000*(INTERVS or 0.5)) end
      end
      self.ref = setTimeout(loop,0)
    end
    function light:startLevelDecrease()
      DEBUG("startLevelDecrease")
      if not self.on then return end
      if self.ref then self.ref=clearTimeout(self.ref) end
      local dimValue = self.raw_bri
      local tDelta = (100/(DIMTIME or 10))*(INTERVS or 0.5)
      local function loop()
        self.ref=nil
        dimValue = math.max(dimValue-tDelta,0)
        self:setValue(dimValue)
        if dimValue > 0 then self.ref=setTimeout(loop,1000*(INTERVS or 0.5)) end
      end
      self.ref = setTimeout(loop,0)
    end
    function light:stopLevelChange()
      DEBUG("stopLevelChange")
      if self.ref then self.ref = clearTimeout(self.ref) end
    end
  end

  class 'LightOnOff'(HueDeviceQA)
  function LightOnOff:__init(info)
    info.type='com.fibaro.binarySwitch'
    info.properties={}
    info.interfaces = {"light"}
    HueDeviceQA.__init(self,info)
    decorateLight(self)
  end

  class 'LightDimmable'(HueDeviceQA)
  function LightDimmable:__init(info)
    info.type='com.fibaro.multilevelSwitch'
    info.properties={}
    info.interfaces = {"light","levelChange"}
    HueDeviceQA.__init(self,info)
    decorateLight(self)
  end

  local UI3 = {
    {label='Ltemperature',text='Temperature'},
    {slider='temperature',onChanged='temperature'},
  }
  fibaro.UI.transformUI(UI3)
  local v3 = fibaro.UI.mkViewLayout(UI3)
  local cb3 = fibaro.UI.uiStruct2uiCallbacks(UI3)

  class 'LightTemperature'(HueDeviceQA)
  function LightTemperature:__init(info)
    info.type='com.fibaro.multilevelSwitch'
    info.properties={ viewLayout=v3, uiCallbacks=cb3 }
    info.interfaces = {'light','levelChange','quickApp'}
    HueDeviceQA.__init(self,info)
    decorateLight(self)
  end

--  local UI4 = {
--    {label='Lsaturation',text='Saturation'},
--    {slider='saturation',onChanged='saturation'},
--    {label='Ltemperature',text='Temperature'},
--    {slider='temperature',onChanged='temperature'},
--  }
--  fibaro.UI.transformUI(UI4)
--  local v4 = fibaro.UI.mkViewLayout(UI4)
--  local cb4 = fibaro.UI.uiStruct2uiCallbacks(UI4)

  class 'ColorLightQA'(HueDeviceQA)
  function ColorLightQA:__init(info)
    info.type='com.fibaro.colorController'
--    info.properties={ viewLayout=v4, uiCallbacks=cb4 }
    info.interfaces = {'light'}
    HueDeviceQA.__init(self,info)
    self.colorComponent = ColorComponents{
      parent = self,
      colorComponents = { -- Comment out components not needed
        warmWhite =  0,
        red = 0,
        green = 0,
        blue = 0,
      },
      dim_time   = 10000,  -- Time to do a full dim cycle, max to min, min to max
      dim_min    = 0,      -- Min value
      dim_max    = 99,     -- Max value
      dim_interv = 1000    -- Interval between dim steps
    }    
    decorateLight(self)
  end

  local function createQA(uid)
    local d,cl = HUE:getResource(uid)
    cl = (HueDeviceTypes[d.rType] or {}).class
    if cl then 
      _G[cl]({uid=uid})
    else
      WARNING("No QA class for %s (%s)",d.rType,uid)
    end
  end

  quickApp:loadQuickerChildren(nil,
    function(dev,uid,className)
      local d = HUE:getResource(uid)
      if d and not d.annotated then
        WARNING("Hue device removed %s (deviceId:%s)",uid,dev.id)
        plugin.deleteDevice(dev.id) 
        return false
      else return true end
    end)

  for uid,info in pairs(HueTable) do
    if HUE:getResource(uid) then
      if not UID2QA[uid] then createQA(uid) end
    else 
      WARNING("Resource %s does not exists: %s",uid,json.encode(info))
    end
  end
end

function QuickApp:onInit()
  HUE = HUEv2Engine
  self:debug(self.name, self.id)
  local ip = self:getVariable("Hue_IP")
  local key = self:getVariable("Hue_User")
  HUEv2Engine.resourceFilter = HueTable
  HUE:initEngine(ip,key,function()
--      HUEv2Engine:dumpDevices()
      HUE:listAllDevices()
      main()
    end)
end
