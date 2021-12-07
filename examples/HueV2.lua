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
  dev:addLIstener('button',function(val)
    end)
end

class 'MotionDevice'()
function MotionDevice:__init(uid)
  self.dev =  HUE:getDevices(uid)
  dev:addLIstener('motion',function(val)
    end)
end

class 'ColorLight'()
function ColorLight:__init(uid)
  self.dev =  HUE:getDevices(uid)
  dev:addLIstener('button',function(val)
    end)
end

local function main()
  local switch = Switch(HueSwitchUID)
  local motion = MotionDevice(HueMotionUID)
  local light = ColorLight(HueSwitchUID)
end

function QuickApp:onInit()
  HUE = HUEv2Engine
  HUE:init(key,ip,main)
end
