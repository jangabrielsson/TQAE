-- luacheck: globals ignore QuickAppBase QuickApp QuickerAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDeviceQA MotionSensorQA TempSensorQA LuxSensorQA SwitchQA HueTable HUEv2Engine
-- luacheck: globals ignore LightOnOff LightDimmable LightTemperature LightColor

local debug

local function DEBUG(tag,str,...) 
  local args = {...}
  local res,stat = pcall(function()
      if debug[tag] then quickApp:debugf(str,table.unpack(args)) end 
    end)
  if not res then
    a=9
  end
end

local function ERROR(str,...) quickApp:errorf(str,...) end
local function WARNING(str,...) quickApp:warningf(str,...) end
fibaro.hue = fibaro.hue or {}
fibaro.hue.DEBUG,fibaro.hue.WARNING,fibaro.hue.ERROR,fibaro.hue.TRACE=DEBUG,WARNING,ERROR,TRACE

local Objects = {}
local HUE,classMap

local function setupChildren(HueClassMap,HueDeviceMap)
  quickApp:loadQuickerChildren(nil,
    function(dev,uid,className)
      local d = HUE:getResource(uid)
      if not d then
        WARNING("Hue device removed %s (deviceId:%s)",uid,dev.id)
        api.delete("/plugins/removeChildDevice/" .. dev.id)
        return false
      else return true end
    end)

  for uid,info in pairs(HueDeviceMap) do
    if not Objects[uid] then
      finfo = HueClassMap[info.model]
      _G[finfo.class]({NEW=true,name=info.name,type=finfo.ftype,uid=uid,class=finfo.class})
    elseif HUE:getResource(uid)==nil then
      WARNING("Resource %s does not exists: %s",uid,json.encode(info))
    end
  end

end

function fibaro.hue.createObject(id,model,name)
  if not Objects[id] then
    finfo = classMap[model]
    return _G[finfo.class]({NEW=true,name=name,type=finfo.ftype,uid=id,class=finfo.class})
  end
end

local function main()
  for id,r in pairs(HUE:getResourceIds()) do
    for prop,_ in ipairs(r:getProps()) do
      r:subscribe(prop,function(key,value)
          quickApp:debugf("E: name:%s, %s=%s",r.name or r.owner.name,key,value)
        end)
    end
  end
  local tim = HUE:getResource("3ab27084-d02f-44b9-bd56-70ea41163cb6")
  --tim:turnOn()
  --setTimeout(function() tim:turnOff() end,4000)
end

function QuickApp:setupHue(HueClassMap,HueDeviceMap,debugFlags)
  self:debugf("%s, deviceId:%s",self.name ,self.id)
  fibaro.debugFlags.extendedErrors=true
  fibaro.hue.debug,debug = debugFlags,debugFlags

  classMap = HueClassMap
  fibaro.hue.Objects = Objects
  HUE = fibaro.hue.Engine
  fibaro.hue.Classes.define()

  local ip = self:getVariable("Hue_IP"):match("(%d+.%d+.%d+.%d+)")
  local key = self:getVariable("Hue_User") --:match("(.+)")
  assert(ip,"Missing Hue_IP - hub IP address")
  assert(key,"Missing Hue_User - Hue hub key")

  HUE:init(ip,key,function()
      setupChildren(HueClassMap,HueDeviceMap)

--      HUEv2Engine:dumpDevices()
--      HUE:dumpDeviceTable()
--      HUE:listAllDevicesGrouped()
      self:post(main) -- Start
    end)
end
