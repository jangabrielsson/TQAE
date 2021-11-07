_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
}
--[[ 

Supported events:
{type='alarm', property='armed', id=<id>, value=<value>}
{type='alarm', property='breached', id=<id>, value=<value>}
{type='alarm', property='homeArmed', value=<value>}
{type='alarm', property='homeBreached', value=<value>}
{type='weather', property=<prop>, value=<value>, old=<value>}
{type='global-variable', property=<name>, value=<value>, old=<value>}
{type='device', id=<id>, property=<property>, value=<value>, old=<value>}
{type='device', id=<id>, property='centralSceneEvent', value={keyId=<value>, keyAttribute=<value>}}
{type='device', id=<id>, property='accessControlEvent', value=<value>}
{type='profile', property='activeProfile', value=<value>, old=<value>}
{type='custom-event', name=<name>}

--]]

version = "V0.1"
local QA=nil
local RUN = true
local EVCOUNT = 0
local format = string.format
local function printf(...) QA:debug(format(...)) end
local function perror(...) QA:error(format(...)) end
local function ptrace(...) QA:trace(format(...)) end
local function pwarn(...) QA:warn(format(...)) end

local subscribers={}

a = [[
Triggers:
{"type":"device","id":88,"value":0}
{"type":"device","id":88,"value":0}
{"type":"device","id":88,"value":0}
]]
a="--[["..a.."--]]"

local function getFilters(code,id)
  local f = code:match("%-%-%[%[[%c%s]*Triggers:[%s%c]*(.-)%-%-%]%]")
  if not f then return {} end
  local filters={}
  f:gsub("(.-)[%c$]+",function(m) 
      local stat,res = pcall(function() return json.decode(m) end)
      if stat then filters[#filters+1]=res
      else pwarn("DeviceID:%s, bad filter:'%s' - ignored",id,m)
      end
    end)
  return filters
end

getFilters(a,0)

local function checkDevice(id)
  if id == plugin.mainDeviceId then return end
  local d = api.get("/devices/"..id)
  local code = d.properties.mainFunction or ""
  if code:match("QuickApp:EVENTS") then
    subscribers[id]=getFilters(code,id)
    printf("DeviceId:%s/%s subscribed",id,#subscribers[id])
  else
    if subscribers[id] then printf("DeviceId:%s unsubscribed",id) end
    subscribers[id]=nil
  end
end

local handlers = {
  ['DeviceModifiedEvent'] = function(d) checkDevice(d.id) end,
  ['DeviceCreatedEvent'] = function(d) checkDevice(d.id) end,
  ['DeviceRemovedEvent'] = function(d) subscribers[d.id]= nil end,
}

function unify(pattern, expr)
  if pattern == expr then return true
  elseif type(pattern) == 'table' then
    if type(expr) ~= "table" then return false end
    for k,v in pairs(pattern) do if not unify(v,expr[k]) then return false end end
    return true
  else return false end
end

function notifySubscribers(evs)
  EVCOUNT=EVCOUNT+#evs
  QA:updateView("info","text","Events:"..EVCOUNT)
  for id,filters in pairs(subscribers) do
    if #filters == 0 then 
      fibaro.call(id,"EVENTS",evs)
      ptrace("Notifying deviceId:%s",id)
    else
      local es = {}
      for _,e in ipairs(evs) do
        for _,f in ipairs(filters) do if f.type==e.type and unify(f,e) then es[#es+1]=e end end
      end
      if #es>0 then 
        fibaro.call(id,"EVENTS",es) 
        ptrace("Notifying deviceId:%s",id)
      end
    end
  end
end

local function pollForEvents(delay)
  local tickEvent = "ERTICK"

  local SUPRESSDEVICE={
    icon=true,
    ConditionCode = true,
    ConditionCodeConverted = true,
    mainFunction=true,
  }

  local EventTypes = { 
    AlarmPartitionArmedEvent = function(d) return {type='alarm', property='armed', id = d.partitionId, value=d.armed} end,
    AlarmPartitionBreachedEvent = function(d) return {type='alarm',property='breached',id =d.partitionId, value=d.breached} end,
    HomeArmStateChangedEvent = function(d) return {type='alarm', property='homeArmed', value=d.newValue} end,
    HomeBreachedEvent = function(d) return {type='alarm', property='homeBreached', value=d.breached} end,
    WeatherChangedEvent = function(d) return {type='weather',property=d.change, value=d.newValue, old=d.oldValue} end,
    GlobalVariableChangedEvent=function(d) 
      if d.variableName ~= "ERTICK" then 
        return {type='global-variable',property=d.variableName,value=d.newValue,old=d.oldValue} 
      end
    end,
    DevicePropertyUpdatedEvent = function(d) 
      if SUPRESSDEVICE[d.property] then return end
      return {type='device', id=d.id, property=d.property, value=d.newValue, old=d.oldValue}
    end,
    CentralSceneEvent = function(d) 
      return {type='device', property='centralSceneEvent', id=d.deviceId, value = {keyId=d.keyId, keyAttribute=d.keyAttribute}}
    end,
    AccessControlEvent = function(d) 
      return {type='device', property='accessControlEvent', id = d.deviceID, value=d} 
    end,
    ActiveProfileChangedEvent = function(d) return {type='profile',property='activeProfile',value=d.newActiveProfile, old=d.oldActiveProfile} end,
    RoomModifiedEvent = function(d) end,
    CustomEvent = function(d) return {type='custom-event', name=d.name} end,
--    PluginChangedViewEvent = function(d) return {type='PluginChangedViewEvent', value=d} end,
    WizardStepStateChangedEvent = function(d) return {type='WizardStepStateChangedEvent', value=d}  end,
    UpdateReadyEvent = function(d) return {type='UpdateReadyEvent', value=d} end,
    SceneRunningInstancesEvent = function(d) return {type='SceneRunningInstancesEvent', value=d} end,
    DeviceRemovedEvent = function(d)  return {type='DeviceRemovedEvent', value=d} end,
    DeviceChangedRoomEvent = function(d) return {type='DeviceChangedRoomEvent', value=d} end,    
    DeviceCreatedEvent = function(d) return {type='DeviceCreatedEvent', value=d} end,
    DeviceModifiedEvent = function(d) return {type='DeviceModifiedEvent', value=d} end,
    SceneStartedEvent = function(d) return {type='SceneStartedEvent', value=d} end,
    SceneFinishedEvent = function(d) return {type='SceneFinishedEvent', value=d} end,
    SceneRemovedEvent = function(d) return {type='SceneRemovedEvent', value=d} end,
    PluginProcessCrashedEvent = function(d) return {type='PluginProcessCrashedEvent', value=d} end,
    onUIEvent = function(d) return {type='uievent', deviceID=d.deviceId, name=d.elementName} end,
  }

  local loop,lastRefresh=nil,0
  local lang="en"
  rand=math.random()/100

  if not hc3_emulator then

    local http = net.HTTPClient()
    function loop()
      local stat,res = 
      http:request(format("http://127.0.0.1:11111/api/refreshStates?last=%d&lang=%s&rand=%f",lastRefresh,lang,rand),{
          success=function(res) 
            local states = json.decode(res.data)
            if states then
              lastRefresh=states.last
              local evs={}
              if RUN then
              for _,e in ipairs(states.events or {}) do
                if handlers[e.type] then handlers[e.type](e.data) end
                if EventTypes[e.type] then evs[#evs+1]=EventTypes[e.type](e.data) end
              end
              if #evs>0 then notifySubscribers(evs) end
              end
            end
            setTimeout(loop,delay)
          end,
          error=function(res) perror("Error: refreshStates:%s",res) setTimeout(loop,1000) end,
        })
    end

  elseif hc3_emulator then
    api.post("/globalVariables",{name=tickEvent,value="Tock!"})

    function loop()
      local states = api.get(format("/refreshStates?last=%d&lang=%s&rand=%f",lastRefresh,lang,rand))
      if states then
        lastRefresh=states.last
        local evs={}
        if RUN then
        for _,e in ipairs(states.events or {}) do
          if handlers[e.type] then handlers[e.type](e.data) end
          if EventTypes[e.type] then evs[#evs+1]=EventTypes[e.type](e.data) end
        end
        if #evs>0 then notifySubscribers(evs) end
        end
      end
      setTimeout(loop,delay)
      fibaro.setGlobalVariable(tickEvent,tostring(os.clock())) -- emit hangs
    end
  end

  loop()

end

function QuickApp:turnOn()
    self:updateProperty("value",true)
    self:updateProperty("state",true)
end

function QuickApp:turnOff()
    self:updateProperty("value",false)
    self:updateProperty("state",false)
end

----------------------------------
function QuickApp:onInit() 
  QA=self
  ptrace("Event watcher, deviceId:%s",self.id)
  for _,d in ipairs(api.get("/devices")) do checkDevice(d.id) end -- rebuild subscriber list at startup
  self:updateView("version","text","Event watcher, "..version)
  self:turnOn()
  pollForEvents(1000)
end

if dofile then
  hc3_emulator.start{
    name = "Event watcher",  -- Name of QA
    poll = 2000,            -- Poll HC3 for triggers every 2000ms
    proxy=true,
    UI={
      {label='version', text=''},
      {{button='on',text='On'},{button='off',text='Off'}},
      {label='info', text=''},
    },
  }
end