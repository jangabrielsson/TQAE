_=loadfile and loadfile("TQAE.lua"){
  user="admin", 
  pwd="admin", 
  host="192.168.1.57",
  temp = "temp/",
  startTime="12/24/2024-07:00",
  copas = true,
}

--%%name="Hue"
--%%quickVars = {["Hue_IP"]=EM.cfg.Hue_IP,["Hue_User"]=EM.cfg.Hue_user }
--%%type="com.fibaro.deviceController"
-- %%proxy = true

--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:lib/HUEv2Engine.lua,hueEngine;
--FILE:lib/colorConversion.lua,colorConversion;

local HueTable = {
  ['3ab27084-d02f-44b9-bd56-70ea41163cb6']=true, -- Tim color lamp
  ['932bd43b-d8cd-44bc-b8bd-daaf72ae6f82']=true, -- Wall switch - RDM001
  ['8a453c82-0072-4223-9c42-f395b5cb0c40']=true, -- Hue smart plug - LOM007
  ['9222ea53-37a6-4ac0-b57d-74bca1cfa23f']=true, -- Hue motion sensor - SML001
  ['a007e50b-0bdd-4e48-bee0-97636d57285a']=true, -- Hue dimmer switch - RWL021
  ['795959f5-9313-4aae-b930-b178b48249e0']=true, -- Rom guest
  ['b5f12b5f-20c7-47a5-8535-c7a20fb9e66d']=true, -- Zone kitchen
}

local HueLightUID = '3ab27084-d02f-44b9-bd56-70ea41163cb6'
local HueWallSwitch = '932bd43b-d8cd-44bc-b8bd-daaf72ae6f82'
local HueSmartPlug = '8a453c82-0072-4223-9c42-f395b5cb0c40'
local HueMotionUID = '9222ea53-37a6-4ac0-b57d-74bca1cfa23f'
local HueSwitchUID = 'a007e50b-0bdd-4e48-bee0-97636d57285a'
local HueRoomUID = '795959f5-9313-4aae-b930-b178b48249e0'
local HueZoneUID = 'b5f12b5f-20c7-47a5-8535-c7a20fb9e66d'

local fmt = string.format
local HUE

class 'HueDevice'()
function HueDevice:__init(uid)
  self.dev =  HUE:getResource(uid)
  self.dev:addListener('connected',function(_,val)
      self:debugf("connected=%s",val)
    end)
  self.dev:addListener('battery',function(_,val)
      self:debugf("battery=%s",val)
    end)
end
function HueDevice:debugf(str,...) quickApp:debugf("%s:%s",self.dev.rName,fmt(str,...)) end

class 'Switch'(HueDevice)
function Switch:__init(uid)
  HueDevice.__init(self,uid)
  self.dev:addListener('button',function(_,val)
      self:debugf("button(%s)=%s",val.id,val.value)
    end)
end

class 'Room'(HueDevice)
function Room:__init(uid)
  HueDevice.__init(self,uid)
  self.dev:addListener('brightness',function(_,val)
      self:debugf("brightness=%s",val)
    end)
  self.dev:addListener('on',function(_,val)
      self:debugf("on=%s",val)
    end)
end

class 'Zone'(HueDevice)
function Zone:__init(uid)
  HueDevice.__init(self,uid)
  self.dev:addListener('brightness',function(_,val)
      self:debugf("brightness=%s",val)
    end)
end

class 'MotionDevice'(HueDevice)
function MotionDevice:__init(uid)
  HueDevice.__init(self,uid)
  self.dev:addListener('motion',function(_,val)
      self:debugf("motion=%s",val)
    end)
  self.dev:addListener('lux',function(_,val)
      self:debugf("lux=%s",val)
    end)
  self.dev:addListener('temp',function(_,val)
      self:debugf("temp=%s",val)
    end)
end

class 'ColorLight'(HueDevice)
function ColorLight:__init(uid)
  HueDevice.__init(self,uid)
  local dev = self.dev
  dev:addListener('on',function(_,val)
      self:debugf("on=%s",val)
    end)
  dev:addListener('brightness',function(_,val)
      self:debugf("brightness=%s",val)
    end)  
  dev:addListener('colorTemp',function(_,val)
      self:debugf("colorTemp=%s",val)
    end)
  dev:addListener('colorXY',function(_,val)
      self:debugf("colorXY=%s",json.encode(val))
      self:debugf("RGB=%s",json.encode({dev.lightService:getRGB()}))
      local r,g,b = self.dev.lightService:getRGB()
      self:debugf("xy=%s",json.encode(fibaro.colorConverter.xy("C").rgb2xy(r,g,b)))
    end)
end
function ColorLight:isOn() return self.dev:isOn() end
function ColorLight:turnOn() return self.dev:turnOn() end
function ColorLight:turnOff() return self.dev:turnOff() end
function ColorLight:getValue() return self.dev:getValue() end                 -- Brightness 0-100
function ColorLight:setValue(value) return self.dev:setValue(value) end
function ColorLight:getTemperature() return self.dev:getTemperature() end     -- 0-255
function ColorLight:setTemperature(temp) return self.dev:setTemperature(temp) end
function ColorLight:getColor() return self.dev:getColor() end                 -- 0-255,0-255,0-255
function ColorLight:setColor(color) return self.dev:setColor(color) end
function ColorLight:getXY() return self.dev:getXY() end                       -- 0-1.0,0-1.0
function ColorLight:setXY(x,y) return self.dev:setXY(x,y) end


local function main()
  local switch = Switch(HueSwitchUID)
  local motion = MotionDevice(HueMotionUID)
  local light = ColorLight(HueLightUID)
  local room = Room(HueRoomUID)  
  local zone = Zone(HueZoneUID)

  --setTimeout(function () light:setXY(HUE.xyColors.green) end,2000)
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
