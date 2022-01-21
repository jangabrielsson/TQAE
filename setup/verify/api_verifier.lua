_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
  offline = true,
  copas = true,
  --readOnly=true,
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

if EM.cfg.offline then EM.create.globalVariable{name="A",value=""} end

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
  local hc3 = "192.168.1.57"
--  local host1 = "192.168.1.183:8976"
  local host1 = EM.IPAddress..":8976"

  self:debug("Collecting API responses from HC3...")
  local ref = {} -- Collect ref responses from HC3
  for _,call in ipairs(GETcalls) do
    local res,code,h = callAPI(hc3,call)
    ref[#ref+1]={res=res,code=code,header=h}
  end

  self:debug("Running verification with TQAE (intentional errors will log...)")
  for i,call in ipairs(GETcalls) do
    local res,code,h = callAPI(host1,call)
    if code==ref[i].code then
      self:trace(fmt("OK - %s (%s)",call,code))
      if type(res)~=type(ref[i].res) then
        self:warning(fmt("Result mismatch  %s (%s/%s)",call,type(res),type(ref[i].res)))
      end
    else
      self:warning(fmt("%s/%s - %s",code,ref[i].code,call))
    end
  end
end

