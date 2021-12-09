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
}

local HueSwitchUID = 'a007e50b-0bdd-4e48-bee0-97636d57285a'
local HueMotionUID = '9222ea53-37a6-4ac0-b57d-74bca1cfa23f'
local HueLightUID = '3ab27084-d02f-44b9-bd56-70ea41163cb6'

local HUE

class 'Switch'()
function Switch:__init(uid)
  self.dev =  HUE:getDevice(uid)
  self.dev:addListener('button',function(_,val)
      quickApp:debugf("button(%s)=%s",val.id,val.event)
    end)
end

class 'MotionDevice'()
function MotionDevice:__init(uid)
  self.dev =  HUE:getDevice(uid)
  self.dev:addListener('motion',function(_,val)
      quickApp:debugf("motion=%s",val)
    end)
  self.dev:addListener('lux',function(_,val)
      quickApp:debugf("lux=%s",val)
    end)
  self.dev:addListener('temp',function(_,val)
      quickApp:debugf("temp=%s",val)
    end)
end

class 'ColorLight'()
function ColorLight:__init(uid)
  self.dev =  HUE:getDevice(uid)
  self.dev:addListener('on',function(_,val)
      quickApp:debugf("on=%s",val)
    end)
  self.dev:addListener('brightness',function(_,val)
      quickApp:debugf("brightness=%s",val)
    end)  
  self.dev:addListener('colorTemp',function(_,val)
      quickApp:debugf("colorTemp=%s",val)
    end)
  self.dev:addListener('colorXY',function(_,val)
      quickApp:debugf("colorXY=%s",json.encode(val))
      quickApp:debugf("RGB=%s",json.encode(self.dev.lightService:getRGB()))
    end)
  self.dev:addListener('connected',function(_,val)
      quickApp:debugf("connected=%s",val)
    end)
end
function ColorLight:turnOn() end
function ColorLight:turnOff() end
function ColorLight:setValue(val) end
function ColorLight:setTemperature(val) end
function ColorLight:setColor(color) end

local function main()
  local switch = Switch(HueSwitchUID)
  local motion = MotionDevice(HueMotionUID)
  local light = ColorLight(HueLightUID)
  
  setTimeout( function () light.dev.lightService:setRGB(127,127,200) end,2000)
end

function QuickApp:onInit()
  HUE = HUEv2Engine
  self:debug(self.name, self.id)
  local ip = self:getVariable("Hue_IP")
  local key = self:getVariable("Hue_User")
  -- HUEv2Engine.deviceFilter = HueTable
  HUE:initEngine(ip,key,function()
--      HUEv2Engine:dumpDevices()
      HUE:listAllDevices()
      main()
    end)
end
