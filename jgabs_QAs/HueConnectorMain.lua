-- luacheck: globals ignore QuickAppBase QuickApp QuickerAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDeviceQA MotionSensorQA TempSensorQA LuxSensorQA SwitchQA HueTable HUEv2Engine
-- luacheck: globals ignore LightOnOff LightDimmable LightTemperature LightColor

local VERSION = 0.1
local SERIAL = "UPD896781234567895" 

local debug
local HueDeviceTable

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

local CONNECTOR_VAR = 'HUERSRC_SUB'
local equal
local HUE

function QuickApp:hueCmd(args)
  if type(args)~="table" then self:error("hueCmd expecting table argument") end
  local hueId = args.id
  local cmd = args.cmd
  local params = args.args
  local rsrc = HUE:getResource(hueId)
  local service = rsrc:getCommand(cmd)
  if not service then
    self:errorf("No command:%s for %s",cmd,hueId)
  else
    local stat,err=pcall(service[cmd],service,table.unpack(params))
    if not stat then
      self:errorf("%s:%s%s -> %s",tostring(hueId),tostring(cmd),json.encode(params or {}),err)
    end
  end
end

----------------------------------------------------------------------------------------
if hc3_emulator and hc3_emulator.EM.Devices[plugin.mainDeviceId].proxy then
  function QuickApp:internalStorageSet(uid,rsrc) fibaro.call(981,"storageSet",uid,rsrc,self.id) return true,200 end
  function QuickApp:internalStorageGet(uid) 
    local res, stat = api.get("/plugins/"..self.id.."/variables/"..uid,"remote")
    return stat == 200 and res.value or nil 
  end
end
local function initResource(uid,rsrc) quickApp:internalStorageSet(uid, rsrc) end
local function updateResource(uid,prop,value)
  local rsrc = quickApp:internalStorageGet(uid) or {}
  rsrc[prop]=value
  quickApp:internalStorageSet(uid, rsrc)
end


local subscriptions={}

local function publish(uid,props)
  local qas = subscriptions[uid] or {}
  if next(qas) then
    quickApp:debugf("Publishing %s",json.encode(props))
    for qa,_ in pairs(qas) do
      quickApp:debugf("...to %s",qa)
      fibaro.call(qa,"HUE_EVENT",uid,props)
    end
  end
end

local function updateSubscriber(id,value)
  local notify=false
  if type(value)=='table' then 
    if next(value)==nil then
      quickApp:debugf("QA:%s unsubscribed",tostring(id))
      for uid,subs in pairs(subscriptions) do subs[id]=nil end
    else
      for _,uid in ipairs(value) do
        if HUE:getResource(uid) then
          subscriptions[uid]=subscriptions[uid] or {}
          subscriptions[uid][id]=true
          quickApp:debugf("QA:%s subscribed to %s",tostring(id),tostring(uid))
          notify=true
        else
          quickApp:errorf("QA:%s bad resource specifier - %s",tostring(id),tostring(uid))
        end
      end
    end
  else
    quickApp:errorf("QA:%s bad subscription list - %s",tostring(id),tostring(value))
  end
  if notify then fibaro.call(id,"HUE_EVENT","INFO",{id=quickApp.id}) end
end

local function checkVars(id,vars)
  for _,var in ipairs(vars or {}) do 
    if var.name==CONNECTOR_VAR then updateSubscriber(id,var.value) end
  end
end

local function main(self,map)
  equal = fibaro.utils.equal
  fibaro._REFRESHSTATERATE = 10
  fibaro.enableSourceTriggers({'quickvar','deviceEvent'},true) -- Get events of these types

  -- At startup, check all QAs for subscriptions
  for _,d in ipairs(api.get("/devices?interface=quickApp") or {}) do
    checkVars(d.id,d.properties.quickAppVariables)
  end

  self:event({type='quickvar',name=CONNECTOR_VAR},        -- If some QA changes subscription
    function(env) updateSubscriber(env.event.id,env.event.value) end) -- update

  self:event({type='deviceEvent',value='removed'},      -- If some QA is removed
    function(env) 
      local id = env.event.id
      if id ~= self.id then
        updateSubscriber(env.event.id,{})               -- update
      end
    end)

  self:event({
      {type='deviceEvent',value='created'},              -- If some QA is added or modified
      {type='deviceEvent',value='modified'}
    },
    function(env)                                        -- update
      local id = env.event.id
      if id ~= self.id then
        checkVars(id,api.get("/devices/"..id).properties.quickAppVariables)
      end
    end)

  local function strip(l) local r={} for k,_ in pairs(l) do r[#r+1]=k end return r end

  for uid,_ in pairs(map) do
    local r = HUE:getResource(uid)
    local props = strip(r:getProps())
    local methods = strip(r:getMethods())
    local rsrcKey = "r"..uid:gsub("-","")
    initResource(rsrcKey,{
        name = r.name or r.owner,
        type = r.type,
        props = props,
        methods = methods,
      })
    local changeMap = {}
    function r:_postEvent(id)
      local c = changeMap
      setTimeout(function() publish(uid,c) end,0)
      changeMap = {}
    end
    for prop,_ in pairs(r:getProps()) do
      self:debugf("Watching %s:%s:%s",uid,r.name or r.owner.name,prop)
      r:subscribe(prop,function(key,value)
          local stat,res = pcall(function() 
              quickApp:debugf("E: name:%s, %s=%s",r.name or r.owner.name,key,tostring(value))
            end)
          if not stat then
            res=stat
          end
          updateResource(rsrcKey,key,value)
          changeMap[key]=value
        end)
    end
    r:publishAll()
  end
end

function QuickApp:deviceTable()
  HUE:dumpDeviceTable(nil,function(id) if next(HueDeviceTable) then return HueDeviceTable[id] else return true end end,HueDeviceTable)
end

function QuickApp:dump()
  HUE:listAllDevicesGrouped()
end

function QuickApp:setupHue(HueDeviceMap,debugFlags)
  self:debugf("%s deviceId:%s, v%s",self.name,self.id,VERSION)
  self:setVersion("HueConnector",SERIAL,VERSION)
  self:setView('info',"HueConnector v%s",VERSION)

  fibaro.debugFlags.extendedErrors=true
  fibaro.hue.debug,debug = debugFlags,debugFlags

  HUE = fibaro.hue.Engine
  HueDeviceTable = HueDeviceMap or {}
  self:internalStorageSet("rdeviceMap",HueDeviceTable)

  local ip = self:getVariable("Hue_IP"):match("(%d+.%d+.%d+.%d+)")
  local key = self:getVariable("Hue_User") --:match("(.+)")
  assert(ip,"Missing Hue_IP - hub IP address")
  assert(key,"Missing Hue_User - Hue hub key")

  HUE:init(ip,key,function()
      if self.main then self:main(HUE) end
--      HUEv2Engine:dumpDevices()
--      HUE:listAllDevicesGrouped()
      self:post(function() main(self,HueDeviceMap) end)-- Start
    end)
end
