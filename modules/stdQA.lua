--[[
TQAE - Tiny QuickApp emulator for the Fibaro Home Center 3
Copyright (c) 2021 Jan Gabrielsson
Email: jan@gabrielsson.com
MIT License

Some standard devices that can be created on-the-fly in the emulator to test against

--]]
local EM,FB = ...

local json,LOG = FB.json,EM.LOG

local devices = {
  ["binarySwitch"] = 
[[
  --%%type="com.fibaro.binarySwitch"
  function QuickApp:turnOn()
    if not self.properties.value then
     self:debug("Turned On")
     self:updateProperty("value",true)
     self:updateProperty("state",true)
    end
  end
  function QuickApp:turnOff()
    if self.properties.value then
    self:debug("Turned Off")
     self:updateProperty("value",false)
     self:updateProperty("state",false)
    end
  end
  function QuickApp:toggle()
    if self.properties.value then self:turnOff() else self:turnOn() end
  end
  function QuickApp:onInit()
    self:debug("onInit",self.name,self.id,self.type)
  end
]],

  ["binarySensor"] = 
[[
  --%%type="com.fibaro.binarySensor"
  local timer
  function QuickApp:breach(s)
    s = tonumber(s) or 10
    self:debug("Sensor breached ("..s.."s)")
    self:updateProperty("value",true)
    if timer then clearTimeout(timer) timer=nil end
    timer = setTimeout(function() 
       self:debug("Sensor safe")
       self:updateProperty("value",false); timer = nil 
      end,
      s*1000)
  end
  function QuickApp:onInit()
    self:debug("onInit",self.name,self.id,self.type)
  end
]],

  ["multilevelSwitch"] = 
[[
  --%%type="com.fibaro.multilevelSwitch"
  function QuickApp:turnOn()
    self:updateProperty("value",99)
    self:updateProperty("state",true) 
  end
  function QuickApp:turnOff()
    self:updateProperty("value",0)
    self:updateProperty("state",false) 
  end
  function QuickApp:setValue(value)
    print("SET",value)
    self:updateProperty("value",value)
  end
  function QuickApp:startLevelIncrease()
    self:debug("startLevelIncrease")
  end
  function QuickApp:startLevelDecrease()
    self:debug("startLevelDecrease")
  end
  function QuickApp:stopLevelChange()
    self:debug("stopLevelChange")
  end
function QuickApp:onInit()
    self:debug("onInit",self.name,self.id,self.type)
  end
]],

  ["multilevelSensor"] = 
[[
  --%%type="com.fibaro.multilevelSensor"
  function QuickApp:setValue(value)
    self:updateProperty("value",value)
  end
  function QuickApp:onInit()
    self:debug("onInit",self.name,self.id,self.type)
  end
]],

  ["player"] = 
[[
  --%%type="com.fibaro.player"
  function QuickApp:play(value)
    self:debug("play")
    self:updateProperty("state", 'play')
  end
  function QuickApp:pause(value)
    self:debug("pause")
    self:updateProperty("state", 'pause')
  end
  function QuickApp:stop(value)
    self:debug("stop")
    self:updateProperty("state", 'stop')
  end
  function QuickApp:prev(value)
    self:debug("prev")
  end
  function QuickApp:next(value)
    self:debug("next")
  end
  function QuickApp:setVolume(volume)
    self:debug("setting volume to:", volume)
    self:updateProperty("volume", volume)
  end
  function QuickApp:setMute(value)
    if mute == 0 or value == false then 
        self:debug("setting mute to:", false)
        self:updateProperty("mute", false)
    else
        self:debug("setting mute to:", true)
        self:updateProperty("mute", true)
    end
  end
  function QuickApp:onInit()
    self:debug("onInit",self.name,self.id,self.type)
  end
]],

  ["rollerShutter"] = 
[[
  --%%type="com.fibaro.rollerShutter"
  function QuickApp:open()
    self:debug("roller shutter opened")
    self:updateProperty("value", 99)
  end

  function QuickApp:close()
    self:debug("roller shutter closed")
    self:updateProperty("value", 0)    
  end

  function QuickApp:stop()
    self:debug("roller shutter stopped ")
  end

-- Value is type of integer (0-99)
  function QuickApp:setValue(value)
    self:debug("roller shutter set to: " .. tostring(value))
    self:updateProperty("value", value)    
   end
  function QuickApp:onInit()
    self:debug("onInit",self.name,self.id,self.type)
  end
]],

  ["doorLock"] = 
[[
  --%%type="com.fibaro.doorLock"
  function QuickApp:secure()
    self:debug("door lock secured")
    self:updateProperty("secured", 255)
  end

  function QuickApp:unsecure()
    self:debug("door lock unsecured")
    self:updateProperty("secured", 0)
  end
  function QuickApp:onInit()
    self:debug("onInit",self.name,self.id,self.type)
    self:updateProperty("secured", 255)
  end
]],


  ["thermostat"] = 
[[
  --%%type="com.fibaro.hvacSystemAuto"
function QuickApp:setThermostatMode(mode)
    self:updateProperty("thermostatMode", mode)
end

-- handle action for setting set point for cooling
function QuickApp:setCoolingThermostatSetpoint(value) 
    self:updateProperty("coolingThermostatSetpoint", value)
end

-- handle action for setting set point for heating
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", value)
end

function QuickApp:onInit()
    self:debug("onInit",self.name,self.id,self.type)
    -- set supported modes for thermostat
    self:updateProperty("supportedThermostatModes", {"Auto", "Off", "Heat", "Cool"})
    -- setup default values
    self:updateProperty("thermostatMode", "Auto")
    self:updateProperty("coolingThermostatSetpoint", 23)
    self:updateProperty("heatingThermostatSetpoint", 20)
end
]]

}

local create = {}
for t,d in pairs(devices) do
  create[t] = function(id,name)
    return id,EM.installQA{id=id,code=d,name=name}
  end
end

EM.create = EM.create or {}
for k,v in pairs(create) do EM.create[k]=v end