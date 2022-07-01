-- luacheck: globals ignore QuickAppBase QuickApp QuickerAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDeviceQA MotionSensorQA TempSensorQA LuxSensorQA SwitchQA HueTable HUEv2Engine
-- luacheck: globals ignore LightOnOff LightDimmable LightTemperature LightColor

local _=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
}

--%%name="Huev2"
--%%type="com.fibaro.deviceController"
--%%quickVars = {["Hue_IP"]=EM.cfg.Hue_IP,["Hue_User"]=EM.cfg.Hue_user }
-- %%proxy=true

--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:test/HUEv2Engine.lua,HueEngine;
--FILE:jgabs_QAs/CoH2/HueColors.lua,Colors;
----------- Code -----------------------------------------------------------

local HUE

local function main()
  for id,r in pairs(HUE:getResourceIds()) do
    for _,prop in ipairs(r:props()) do
      r:subscribe(prop,function(key,value)
          quickApp:debugf("E: name:%s, %s=%s",r.name or r.owner.name,key,value)
        end)
    end
  end
end

function QuickApp:onInit()
  self:debugf("%s, deviceId:%s",self.name ,self.id)
  HUE = HUEv2Engine
  self:debug(self.name, self.id)
  local ip = self:getVariable("Hue_IP")
  local key = self:getVariable("Hue_User")
  HUEv2Engine.resourceFilter = HueTable
  HUE:initEngine(ip,key,function()
--      HUEv2Engine:dumpDevices()
      HUE:listAllDevices()
      self:post(main)
    end)
end
