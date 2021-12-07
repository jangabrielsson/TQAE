_=loadfile and loadfile("TQAE.lua"){
  user="admin", 
  pwd="admin", 
  host="192.168.1.57",
  temp = "temp/",
  startTime="12/24/2024-07:00",
}

--%%name="Hue"
--%%quickVars = {["Hue_IP"]=EM.cfg.Hue_IP,["Hue_User"]=EM.cfg.Hue_user }
--%%type="com.fibaro.deviceController"
-- %%proxy = true

--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:lib/HUEv2Engine.lua,hueEngine;
--FILE:lib/colorConversion.lua,colorConversion;

local HUE

class 'Switch'()
function Switch:__init(uid)
  self.dev =  HUE:getDevices(uid)
  dev:addListener('button',function(_,val)
      quickApp:debug("button(%s)=%s",val.id,val.event)
    end)
end

class 'MotionDevice'()
function MotionDevice:__init(uid)
  self.dev =  HUE:getDevices(uid)
  dev:addListener('motion',function(_,val)
      quickApp:debug("motion=%s",val)
    end)
  dev:addListener('lux',function(_,val)
      quickApp:debug("lux=%s",val)
    end)
  dev:addListener('temp',function(_,val)
      quickApp:debug("temp=%s",val)
    end)
end

class 'ColorLight'()
function ColorLight:__init(uid)
  self.dev =  HUE:getDevices(uid)
  dev:addListener('on',function(_,val)
      quickApp:debug("on=%s",val)
    end)
  dev:addListener('brightness',function(_,val)
      quickApp:debug("brightness=%s",val)
    end)  
  dev:addListener('colorTemp',function(_,val)
      quickApp:debug("colorTemp=%s",val)
    end)
  dev:addListener('colorXY',function(_,val)
      quickApp:debug("colorXY=%s",json.encode(val))
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
  local light = ColorLight(HueSwitchUID)
end

function QuickApp:onInit()
  HUE = HUEv2Engine
  HUE:init(key,ip,main)
end
