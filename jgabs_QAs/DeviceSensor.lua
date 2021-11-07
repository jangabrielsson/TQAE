_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
}

--%%name="DeviceSensor"
--%%quickVars = {["devices"]="21 214 55"}
--%%type="com.fibaro.motionSensor"

--FILE:Libs/fibaroExtra.lua,fibaroExtra;

----------- Code -----------------------------------------------------------

local interval = 1
local devices = {}
local delay = 0
local isOn = false

local function valueOf(v) return type(v)=='number' and v > 0 or v end

local function checkDevices(self,devices)
  local on,last = false,-1
  for _,d in ipairs(devices) do
    local value = api.get("/devices/"..d.deviceId.."/properties/value")
    if value then
      d.value = valueOf(value.value)
      d.last = value.modified or os.time()
      on = on or d.value
      last = math.max(last,d.last)
    end
  end
  last = os.time()-last
  if last < delay and not on then -- not off long enough
    self:setView("info","text","Delay %ds (%ds)",delay,last)
    return
  end
  if on ~= isOn then
    self:setView("info","text","Delay %ds (%ds)",delay,delay)
    isOn = on
    self:updateProperty("value",on)
    self:updateProperty("state",on)
  end
end

function QuickApp:onInit()
  self:debug(self.name,self.id)
  self:updateView("name","text",self.name)
  deviceStr = self:getVariable("devices")
  self:setView("devices","text","Device:%s",deviceStr)
  delay = self:getVariable("delay")
  delay = tonumber(delay) or 0
  deviceStr:gsub("%d+", function(device)
      local value = api.get("/devices/"..device.."/properties/value")
      if value then
        devices[#devices+1]={
          deviceId=tonumber(device),
          last = value.modified or os.time(),
          value = valueOf(value.value)
        }
      end
    end)
  if #devices == 0 then
    self:debug("No devices configured. Please set quickApp variable 'devices' with list of devices")
  end
  self:updateProperty("value",false)
  self:updateProperty("state",false)
  setInterval(function() checkDevices(self,devices) end,1000*interval)
end

