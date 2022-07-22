-- luacheck: globals ignore QuickAppBase QuickApp QuickerAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDeviceQA MotionSensorQA TempSensorQA LuxSensorQA SwitchQA HueTable HUEv2Engine
-- luacheck: globals ignore LightOnOff LightDimmable LightTemperature LightColor

local version = 0.2

local HueClasses = { version = version }
local DEBUG,WARNING,ERROR,TRACE
fibaro.hue = fibaro.hue or {}
fibaro.hue.Classes = HueClasses
local HUE,Objects
local function setup()
  DEBUG,WARNING,ERROR,TRACE=fibaro.hue.DEBUG,fibaro.hue.WARNING,fibaro.hue.ERROR,fibaro.hue.TRACE
  HUE,Objects = fibaro.hue.Engine,fibaro.hue.Objects
end

local function classes() 
  class 'HueClass'(QuickerAppChild)
  function HueClass:__init(dev)
    local uid = dev.uid
    self.uid = uid
    local d = HUE:getResource(uid)
    self.d = d
    self.props = d:getProps()
    self.methods = d:getMethods()

    local interfaces = dev.interfaces or {}
    if self.props.power_state then interfaces[#interfaces+1]='battery' end
    local args =    {
      name = dev.name,
      uid  = dev.uid,
      type = dev.type,
      quickVars = dev.quickVars,
      properties = dev.properties,
      interfaces = interfaces,
    }

    _,created = QuickerAppChild.__init(self,args)
    Objects[self.uid]=self

    if self.props.power_state then d:subscribe("power_state",
        function(_,v) 
          self:updateProperty("batteryLevel",v.battery_level)
          DEBUG("class","Battery '%s':%s = %s%%",self.name,self.id,v.battery_level)
        end) 
    end
    if self.props.status then d:subscribe("status",
        function(_,v) 
          v = v=="connected"
          self:updateProperty("dead",not v)
          DEBUG("class","Connected '%s':%s %s",self.name,self.id,v)
        end) 
    end

    return self,created
  end

  function HueClass:send(args) end -- raw Hue command

  local btnMap = {initial_press="Pressed",['repeat']="HeldDown",short_release="Released",long_release="Released"}
  class 'Switch'(HueClass)
  function Switch:__init(dev)
    HueClass.__init(self,dev)
    if self.props.button then self.d:subscribe("button",
        function(_,v,s)
          local key = s.metadata.control_id
          local modifier = btnMap[v]
          -- self:updateProperty("value",v)
          local data = {
            type =  "centralSceneEvent",
            source = self.id,
            data = { keyAttribute = modifier, keyId = key }
          }
          local a,b = api.post("/plugins/publishEvent", data)
          DEBUG("class","Button '%s':%s btn:%s = %s",self.name,self.id,key,modifier)
        end) 
    end
  end

  class 'Temperature'(HueClass)
  function Temperature:__init(dev)
    HueClass.__init(self,dev)
    if self.props.temperature then self.d:subscribe("temperature",
        function(_,v,s)  
          self:updateProperty("value",v)
          DEBUG("class","Temperature '%s':%s = %s",self.name,self.id,v)
        end) 
    end
  end

  class 'Lux'(HueClass)
  function Lux:__init(dev)
    HueClass.__init(self,dev)
    if self.props.light then self.d:subscribe("light",
        function(_,v,s)
          v = math.pow(10, (v - 1) / 10000)
          self:updateProperty("value",v)
          DEBUG("class","Lux '%s':%s = %s",self.name,self.id,v)
        end) 
    end
  end

  class 'MotionSensor'(HueClass)
  function MotionSensor:__init(dev)
    HueClass.__init(self,dev)
    if self.props.motion then self.d:subscribe("motion",
        function(_,v,s)
          self:updateProperty("value",v)
          DEBUG("class","Motion '%s':%s = %s",self.name,self.id,v)
        end) 
    end
    if self.new then
      fibaro.hue.createObject(self.d:findServiceByType('temperature')[1].id,"temperature",self.name..",temp")
      fibaro.hue.createObject(self.d:findServiceByType('light_level')[1].id,"light_level",self.name..",lux")
    end
  end

  local function setupLightMethods(self,tag)
    if self.props.on then 
      self.d:subscribe("on",function(_,v,s) self:updateProperty('state',true) DEBUG("class","%s.on '%s':%s = %s",tag,self.name,self.id,v) end) 
      function self:turnOn() 
        self.service:turnOn()
        self:updateProperty('state',false) 
        self:updateProperty('value',0) 
      end
      function self:turnOff() 
        self.service:turnOff()
        self:updateProperty('state',false) 
        self:updateProperty('value',self.bri or 100) 
      end
    end
    if self.props.dimming and self.service.rsrc.dimming then 
      local min_dim = self.service.rsrc.dimming.min_dim_level or 1
      self.d:subscribe("dimming",function(_,v,s) 
          self.bri = math.floor(v+0.5)
          self:updateProperty('value',self.bri) 
          DEBUG("class","%s.dimming '%s':%s = %s",tag,self.name,self.id,self.bri) 
        end)
      function self:setValue(v) self.service:setDim(v) end
      function self:startLevelIncrease()
        self.service:sendCmd({dimming={brightness=100},dynamics={duration=10000}})
      end
      function self:startLevelDecrease()
        self.service:sendCmd({dimming={brightness=0},dynamics={duration=10000}})
      end
      function self:stopLevelChange() self:turnOn() end
    end
    if self.props.color and self.service.rsrc.color then
      local gamut = self.service.rsrc.color.gamut_type
      local cc = fibaro.colorConverter.xy(gamut)
      self.d:subscribe("color",function(_,v,s)
          local r,g,b = cc.xyb2rgb(v.x,v.y,(self.bri or 100)/100.0)
          DEBUG("class","%s.color '%s':%s = %s,%s,%s - %s",tag,self.name,self.id,r,g,b,(json.encode(v)))
        end)
      function self:setColor(r,g,b,w)
        local xy = cc.rgb2xy(r,g,b)
        self.service:setColor(xy.x,xy.y)
        if w then self.setValue(w) end
      end
    end
    if self.props.color_temperature and self.service.rsrc.color_temperature then 
      local ms = self.service.rsrc.color_temperature.mirek_schema
      self.d:subscribe("color_temperature",function(_,v,s)
          DEBUG("class","%s.ctemp '%s':%s = %s",tag,self.name,self.id,v) 
        end) 
      function self:setTemperature(v)  self.service:setTemperature(v) end
    end
    function self:SEND(x) self.service:sendCmd(x) end
  end

  class 'Room'(HueClass)
  function Room:__init(dev)
    HueClass.__init(self,dev)
    self.service = self.d:findServiceByType('light')[1]
    setupLightMethods(self,"Room")
  end

  class 'Zon'(HueClass)
  function Zon:__init(dev)
    HueClass.__init(self,dev)
    self.service = self.d:findServiceByType('light')[1]
    setupLightMethods(self,"Zon")
  end

  class 'ColorLight'(HueClass)
  function ColorLight:__init(dev)
    HueClass.__init(self,dev)
    self.service = self.d:findServiceByType('light')[1]
    setupLightMethods(self,"CLight")
  end

  class 'DimmableLight'(HueClass)
  function DimmableLight:__init(dev)
    HueClass.__init(self,dev)
    self.service = self.d:findServiceByType('light')[1]
    setupLightMethods(self,"DLight")
  end
end

function HueClasses.define()
  setup()
  classes()
end



