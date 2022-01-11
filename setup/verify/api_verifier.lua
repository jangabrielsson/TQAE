_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
  copas = true
}

--%%name="API Verifier"
--%%type="com.fibaro.binarySwitch"

local fmt = string.format
local EM = hc3_emulator.EM

local function callAPI(host,path,args) -- GET/icons...
  local method,call = path:match("(.-)(/.*)")
  local base = fmt("http://%s/api",host)
  return EM.HC3Request(method,call,args,{base=base})
end

local GETcalls = {
  "GET/devices",
  "GET/devices/1",
  "GET/globalVariables",
  "GET/globalVariables/A", -- 200
  "GET/globalVariables/XYZ", --404
  "GET/energy/devices",
  "GET/alarms/v1/devices",
  "GET/alarms/v1/partitions",
  "GET/customEvents",
  "GET/panels/location",
  "GET/settings/location",
  "GET/settings/info",
  "GET/debugMessages",
  "GET/home",
  "GET/icons",
  "GET/iosDevices",
  "GET/notificationCenter",
  "GET/profiles",
  "GET/profiles/1",
  "GET/refreshStates",
  "GET/rooms",
  "GET/rooms/219",
  "GET/scenes",
  "GET/scenes/10",
  "GET/sections",
  "GET/sections/219",
  "GET/users",


  "GET/users/2",
  "GET/weather",

}

function QuickApp:onInit()
  self:debug(self.name, self.id)
  local host1 = "192.168.1.18:8976"
  local host2 = "192.168.1.57"
  for _,call in ipairs(GETcalls) do
    local res1,code1,h1 = callAPI(host1,call)
    local res2,code2,h2 = callAPI(host2,call)
    if code1==code2 then
      self:trace(fmt("OK - %s (%s)",call,code1))
    else
      self:warning(fmt("%s/%s - %s",code1,code2,call))
    end
  end
end

