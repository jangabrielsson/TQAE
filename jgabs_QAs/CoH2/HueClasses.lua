-- luacheck: globals ignore QuickAppBase QuickApp QuickerAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property

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

local function round(x) return math.floor(x+0.5) end

local function classes() 
  class 'HueClass'(QuickerAppChild)
  function HueClass:__init(dev)
    local uid = dev.uid
    local d = HUE:getResource(uid)
    local props = d:getProps()

    local interfaces = dev.interfaces or {}
    if props.power_state then interfaces[#interfaces+1]='battery' end
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
    print("Inited ",uid,created)
    Objects[uid]=self
    self.uid = uid
    self.d = d
    self.props = props
    self.methods = d:getMethods()

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
  function HueClass:postInit() self.d:publishAll() end
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
    self:postInit()
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
    self:postInit()
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
    self:postInit()
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
    if self.NEW then
      fibaro.hue.createObject(self.d:findServiceByType('temperature')[1].id,"temperature",self.name..",temp")
      fibaro.hue.createObject(self.d:findServiceByType('light_level')[1].id,"light_level",self.name..",lux")
    end
    self:postInit()
  end

  local V255 = 255.0
  local function setupLightMethods(self,tag)
    self._hue = {}
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
        self:updateProperty('value',99) 
      end
      self.on = self.turnOn
      self.off = self.turnOff
    end
    if self.props.dimming and self.service.rsrc.dimming then 
      local min_dim = self.service.rsrc.dimming.min_dim_level or 1
      self.d:subscribe("dimming",function(_,v,s) 
          local bri = round(V255*v/100)
          self:updateProperty('value',round(v))
          --self:updateProperty('brightness',bri)
          self:setView('brightness',"value",bri)
          DEBUG("class","%s.dimming '%s':%s = %s",tag,self.name,self.id,bri)
        end)
      function self:setValue(v) -- 0-100
        self.service:setDim(v) self:setView("brightness","value",round(V255*v/100.0))
      end
      function self:startLevelIncrease()
        self.service:sendCmd({dimming={brightness=100},dynamics={duration=10000}})
      end
      function self:startLevelDecrease()
        self.service:sendCmd({dimming={brightness=0},dynamics={duration=10000}})
      end
      function self:stopLevelChange() self.service:sendCmd({dimming_delta={action='stop'}}) end
    end

    if self.props.color and self.service.rsrc.color then
      local cc = fibaro.colorConversion
      local G =  cc.gamut(self.service.rsrc.color.gamut_type)
      self.hsv,self._t = {h=0,s=0,v=100},0
      self.d:subscribe("color",function(_,v,_)
          self.xy=v
          if os.time()-self._t > 2 then
            local h,s,vv = cc.xyv2hsv(v.x,v.y,self.hsv.v,G)  
            local h1,s1=round((h/360)*65535),round((s/100)*V255) 
            DEBUG("class","%s.color '%s':%s = %s,%s - %s",tag,self.name,self.id,h,s,(json.encode(v)))
            self:updateProperty('hue',h1)
            self:setView('hue',"value",h1)
            self:updateProperty('saturation',s1)
            self:setView('saturation',"value",s1)
            self.hsv={h=h,s=s,v=vv}
          end
        end)
      function self:setColor(r,g,b,w) -- 0-255
        local bri = w and w > 0 and round(100.0*w/V255) or nil -- normalize 0-100
        local x,y = cc.rgb2xy(r,g,b,G)
        self.service:setColor(x,y)
      end

      function self:hue(ev) self:changeHue(ev.values[1]) end
      function self:saturation(ev) self:changeSaturation(ev.values[1]) end
      function self:brightness(ev) self:changeBrightness(ev.values[1]) end

      function self:changeHue(h)
        h = round((h/65535)*360)
        local x,y,vv = cc.hsv2xyv(h,self.hsv.s,self.hsv.v,G)
        self.hsv.h = h
        self._t = os.time()
        self.service:setColor(x,y)
      end
      function self:changeSaturation(s)
        s = round((s/V255)*100)
        local x,y,vv = cc.hsv2xyv(self.hsv.h,s,self.hsv.v,G)
        self.hsv.s = s
        self._t = os.time()
        self.service:setColor(x,y)
      end
      function self:changeBrightness(bri)
        self:setValue(round(100.0*bri/255.0))
      end

    end
    if self.props.color_temperature and self.service.rsrc.color_temperature then 
      local ms = self.service.rsrc.color_temperature.mirek_schema
      self.d:subscribe("color_temperature",function(_,v,s)
          if v==nil then return end
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
    self:postInit()
  end

  class 'Zon'(HueClass)
  function Zon:__init(dev)
    HueClass.__init(self,dev)
    self.service = self.d:findServiceByType('light')[1]
    setupLightMethods(self,"Zon")
    self:postInit()
  end

  class 'ColorLight'(HueClass)
  function ColorLight:__init(dev)
    HueClass.__init(self,dev) 
    self.service = self.d:findServiceByType('light')[1]
    setupLightMethods(self,"CLight")
    self:postInit()
  end

  class 'ColorLight2'(HueClass)
  function ColorLight:__init(dev)
    HueClass.__init(self,dev) 
    self.service = self.d:findServiceByType('light')[1]
    setupLightMethods(self,"CLight")
    self:postInit()
  end
  
  class 'DimmableLight'(HueClass)
  function DimmableLight:__init(dev)
    HueClass.__init(self,dev) 
    self.service = self.d:findServiceByType('light')[1]
    setupLightMethods(self,"DLight")
    self:postInit()
  end
end

function HueClasses.define()
  setup()
  classes()
end



