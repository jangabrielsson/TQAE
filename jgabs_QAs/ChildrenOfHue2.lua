-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDevice ZLLSwitch ZLLTemperature ZLLLightLevel BinarySensor BinarySwitch 
-- luacheck: globals ignore Dimmable_light LightGroup Color_light ZLLPresence Extended_color_light

_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  copas=true,
  debug = { onAction=true, http=false, UIEevent=true },
}

--%%name="HueTest"
--%%quickVars = {["Hue_IP"]=EM.cfg.Hue_IP,["Hue_User"]=EM.cfg.Hue_user }
--%%type="com.fibaro.binarySwitch"

--FILE:lib/fibaroExtra.lua,fibaroExtra;

local fmt = string.format
local url,app_key
local E = fibaro.event
local P = fibaro.post
local v2 = "1948086000"
local Devices = {}

local HueDeviceTypes = {
  ["Hue motion sensor"]      = {types={"SML001"},          class="MotionSensor"},
  ["Hue color lamp"]         = {types={"LCA001","LCT015"}, class="ColorLamp"},
  ["Hue ambiance lamp"]      = {types={"LTA001"},          class="DimLamp"},
  ["Hue white lamp"]         = {types={"LWA001"},          class="DimLamp"},
  ["Hue color candle"]       = {types={"LCT012"},          class="ColorLamp"},
  ["Hue filament bulb"]      = {types={"LWO003"},          class="WhiteLamp"},
  ["Hue dimmer switch"]      = {types={"RWL021"},          class="DimmerSwitch"},
  ["Hue wall switch module"] = {types={"RDM001"},          class="Switch"},
  ["Hue smart plug"]         = {types={"LOM007"},          class="WhiteLamp"},
--services: {rid="...", rtype="button"}
  ["Hue color spot"]         = {types={"LCG0012"},         class="ColorLamp"},
}

class 'HueDevice'()
function HueDevice:__init(dev)
  self.dev = dev
end

class 'MotionSensor'()
function MotionSensor:__init(dev)
  HueDevice.__init(self,dev)
end

class 'ColorLamp'()
function ColorLamp:__init(dev)
  HueDevice.__init(self,dev)
end

class 'DimLamp'()
function DimLamp:__init(dev)
  HueDevice.__init(self,dev)
end

class 'WhiteLamp'()
function WhiteLamp:__init(dev)
  HueDevice.__init(self,dev)
end
function WhiteLamp:change(id,ev)
  quickApp:debugf("%s %s",id,ev)
end

class 'DimmerSwitch'()
function DimmerSwitch:__init(dev)
  HueDevice.__init(self,dev)
  local buttons,n = {},1
  self.buttons = buttons
  for _,s in ipairs(dev.services) do
    if s.rtype=='button'  then buttons[s.rid]=n; n=n+1 end
  end
end
function DimmerSwitch:button(id,ev)
  quickApp:debugf("Button %s %s",self.buttons[id],ev.last_event)
end

class 'Switch'()
function Switch:__init(dev)
  HueDevice.__init(self,dev)
end

local function call(api,event) 
  net.HTTPClient():request(url..api,{
      options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = app_key }},
      success = function(res) P({type=event,success=json.decode(res.data)}) end,
      error = function(err) P({type=event,error=err})  end,
    })
end

E({type='START'},function() call("/api/config",'HUB_VERSION') end)

E({type='HUB_VERSION',success='$res'},function(env)
    if env.p.res.swversion >= "1948086000" then
      quickApp:debugf("V2 api available (%s)",env.p.res.swversion)
    end
    call("/clip/v2/resource/device",'GET_DEVICES')
  end)

E({type='HUB_VERSION',error='$err'},function(env)
    quickApp:errorf("Connections error from Hub: %s",env.p.err)
  end)

--{id = "2219eadd-9464-4149-b52d-073ed1d9754a", id_v1 = "/lights/26", metadata = {archetype = "spot_bulb", name = "Köksö2"}, product_data = {certified = true, manufacturer_name = "Signify Netherlands B.V.", model_id = "LCG002", product_archetype = "spot_bulb", product_name = "Hue color spot", software_version = "1.88.2"}, services = {{rid = "658e876f-cd17-4685-b270-8f5fa66bcb48", rtype = "light"}, {rid = "9f444fb9-5a90-4e50-a414-d01be0044023", rtype = "zigbee_connectivity"}, {rid = "99f60a5e-6f22-4521-891a-7bbd752cc58b", rtype = "entertainment"}}, type = "device"}

E({type='GET_DEVICES',success='$res'},function(env)
    for _,d in ipairs(env.p.res.data or {}) do
      if not Devices[d.id] then
        if HueDeviceTypes[d.product_data.product_name] then
          quickApp:debugf("Dev: %s",d.metadata.name)
          Devices[d.id]=_G[HueDeviceTypes[d.product_data.product_name].class](d)
        else
          quickApp:debugf("Unknown device: %s - %s",d.product_name,d.metadata.name)
        end
      end
    end
  end)

E({type='GET_DEVICES',error='$err'},function(env) quickApp:error(env.p.err) end)

--[[
curl --insecure -N -H 'hue-application-key: <appkey>' -H 'Accept: text/event-stream' https://<ipaddress>/eventstream/clip/v2
--]]

local HueHandler = {}
function HueHandler.button(e)
  if Devices[e.id] then return Devices[e.id]:button(e.id,e.button) 
  elseif e.owner and Devices[e.owner.rid] then return Devices[e.owner.rid]:button(e.id,e.button) end
end
function HueHandler.light(e)
  if Devices[e.id] then return Devices[e.id]:change(e.id,e.button) end
end
function HueHandler.light_group(e)
  if Devices[e.id] then return Devices[e.id]:change(e.id,e.button) end
end

local function fetchEvents()
  local getw
  i = 1
  local eurl = url.."/eventstream/clip/v2"
  local args = { options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = app_key }}}
  function args.success(res)
    local data = json.decode(res.data)
    for _,e in ipairs(data) do
      if e.type=='update' then
        data = e.data
        for _,e in ipairs(e.data) do
          if HueHandler[e.type] then HueHandler[e.type](e)
          else
            quickApp:warningf("Unknow resource type:%s",e)
          end
        end
      else
        quickApp:debugf("New event type:%s",e.type)
        quickApp:debugf("%s",json.encode(e))
      end
    end
    getw()
  end
  function args.error(err) quickApp:errorf("/eventstream :%s",err)  getw() end
  function getw() net.HTTPClient():request(eurl,args) end
  setTimeout(getw,0)
end

function QuickApp:onInit()
  url = self:getVariable("Hue_IP")
  app_key = self:getVariable("Hue_User")

  url = fmt("https://%s:443",url)

  self:post({type='START'})
  fetchEvents()
end

