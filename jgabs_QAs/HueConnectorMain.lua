-- luacheck: globals ignore QuickAppBase QuickApp QuickerAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDeviceQA MotionSensorQA TempSensorQA LuxSensorQA SwitchQA HueTable HUEv2Engine
-- luacheck: globals ignore LightOnOff LightDimmable LightTemperature LightColor

local VERSION = 0.12
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
  if type(args)~="table" then self:error("hueCmd expecting table argument") return end
  local hueId = args.id
  local cmd = args.cmd
  local params = args.args
  local rsrc = HUE:getResource(hueId)
  local service = rsrc:getCommand(cmd)  -- ToDo: Optimize with cache!
  if not service then self:errorf("No command:%s for %s",cmd,hueId) return end
  local stat,err=pcall(service[cmd],service,table.unpack(params))
  if not stat then
    self:errorf("%s:%s%s -> %s",tostring(hueId),tostring(cmd),json.encode(params or {}),err)
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
local rsrcKeys = {}
local function getResourceKey(uid)
  local map = rsrcKeys[uid]
  if map then return map else rsrcKeys[uid]="r"..uid:gsub('-',"") return rsrcKeys[uid] end
end
local function initResource(uid,rsrc) quickApp:internalStorageSet(getResourceKey(uid), rsrc) end
local function getResource(uid) return quickApp:internalStorageGet(getResourceKey(uid)) end
local function updateResource(uid,prop,value)
  local key = getResourceKey(uid)
  local rsrc = quickApp:internalStorageGet(key) or {}
  rsrc[prop]=value
  quickApp:internalStorageSet(key, rsrc)
end


local subscriptions={}

local function publishToQA(id,uid)
  local props = getResource(uid)
  if props and next(props) then
    quickApp:debugf("Publishing %s to QA%s",uid,id)
    fibaro.call(id,"HUE_EVENT",uid,props)
  end
end

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

local function subscribeTo(uid)
  local r = HUE:getResource(uid)
  local function strip(l) local r={} for k,_ in pairs(l) do r[#r+1]=k end return r end
  local props = strip(r:getProps())
  local methods = strip(r:getMethods())
  initResource(uid,{
      name = r.name or r.owner,
      type = r.type,
      props = props,
      methods = methods,
    })
  local changeMap = {}
  function r:_postEvent(id)
    local c = changeMap
    --if next(c) then publish(uid,c) end
    if next(c) then setTimeout(function() publish(uid,c) end,0) end
    changeMap = {}
  end
  for prop,_ in pairs(r:getProps()) do
    quickApp:debugf("Watching %s:%s:%s",uid,r.name or r.owner.name,prop)
    r:subscribe(prop,function(key,value,obj)
        quickApp:debugf("E: name:%s, %s=%s",r.name or r.owner.name,key,tostring(value))
        value = {value=value, timestamp=os.time()}
        if prop=='button' then value.keyId = obj.metadata.control_id or 0 end
        updateResource(uid,key,value)
        changeMap[key]=value
      end)
  end
  r:publishAll()
end

local function unsubscribeTo(uid)
  local r = HUE:getResource(uid)
  for prop,_ in pairs(r:getProps()) do
    quickApp:debugf("Unwatching %s:%s:%s",uid,r.name or r.owner.name,prop)
    r:unsubscribe(prop,true)
  end
end

local function updateSubscriber(id,value)
  fibaro.call(id,"HUE_EVENT","INFO",{id=quickApp.id})
  if type(value)=='table' then
    if next(value)==nil then
      for uid,subs in pairs(subscriptions) do 
        if subs[id] then quickApp:debugf("QA:%s unsubscribed to %s",tostring(id),uid) end
        subs[id]=nil
        if next(subs)==nil then
          unsubscribeTo(uid)
        end
      end
    else
      local sm = {}
      for _,uid in ipairs(value) do
        if HUE:getResource(uid) then
          sm[uid]=true
          quickApp:debugf("QA:%s subscribed to %s",tostring(id),tostring(uid))
          if subscriptions[uid] then
            subscriptions[uid][id]=true
            publishToQA(id,uid)
          else
            subscriptions[uid]={[id]=true}
            subscribeTo(uid)
          end
        else
          quickApp:errorf("QA:%s bad resource specifier - %s",tostring(id),tostring(uid))
        end
      end
      for uid,subs in pairs(subscriptions) do
        if not sm[uid] then subs[id]=nil end
      end
    end
  else
    quickApp:errorf("QA:%s bad subscription list - %s",tostring(id),tostring(value))
  end
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
    function(env) 
      updateSubscriber(env.event.id,env.event.value) 
    end) -- update

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

end

local allProps,fmt = { "type","name","model","room","zone","ref" },string.format
function QuickApp:deviceTable()
  local r={}
  for uid,r0 in pairs(HueDeviceTable) do r[#r+1]={uid,r0.type,r0} end
  table.sort(r,function(a,b) return a[2]< b[2] or (a[2]==b[2] and a[1] < b[1]) end)
  for _,i in ipairs(r) do
    local b,k,v = {},i[1],i[3]
    for _,p in ipairs(allProps) do
      if v[p]~=nil then b[#b+1]=fmt("%s='%s', ",p,tostring(v[p])) end
    end
    print("['"..k.."']","= {",table.concat(b),"},")
  end
end

function QuickApp:dump() HUE:listAllDevicesGrouped() end

function QuickApp:setupHue(_,debugFlags)
  self:debugf("%s deviceId:%s, v%s",self.name,self.id,VERSION)
  self:setVersion("HueConnector",SERIAL,VERSION)
  self:setView('info',"HueConnector v%s",VERSION)
  fibaro.enableSourceTriggers({'quickvar','deviceEvent'},true) -- Get events of these types

  fibaro.debugFlags.extendedErrors=true
  fibaro.debugFlags.logTrigger=false
  --fibaro.debugFlags.sourceTrigger=true
  --fibaro.debugFlags._allRefreshStates=true
  fibaro.hue.debug,debug = debugFlags,debugFlags

  HUE = fibaro.hue.Engine

  local ip = self:getVariable("Hue_IP"):match("(%d+.%d+.%d+.%d+)")
  local key = self:getVariable("Hue_User") --:match("(.+)")
  assert(ip,"Missing Hue_IP - hub IP address")
  assert(key,"Missing Hue_User - Hue hub key")

  HUE:init(ip,key,function()
      HueDeviceTable = HUE:createDeviceTable()
      if self.main then self:main(HUE) end
      self:internalStorageSet("rdeviceMap",HueDeviceTable)
      self:post(function() main(self) end)-- Start
    end)
end
