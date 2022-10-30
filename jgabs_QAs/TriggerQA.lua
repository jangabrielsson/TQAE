-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator
_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { 
    onAction=true, http=false, UIEevent=true 
  },
  copas=true
}

--[[ 

Supported events:
{type='alarm', property='armed', id=<id>, value=<value>}
{type='alarm', property='breached', id=<id>, value=<value>}
{type='alarm', property='homeArmed', value=<value>}
{type='alarm', property='homeBreached', value=<value>}
{type='alarm', property='activated', id=<id>, seconds=<seconds>}
{type='weather', property=<prop>, value=<value>, old=<value>}
{type='global-variable', property=<name>, value=<value>, old=<value>}
{type='quickvar', id=<id>, name=<name>, value=<value>; old=<old>}
{type='device', id=<id>, property=<property>, value=<value>, old=<value>}
{type='device', id=<id>, property='centralSceneEvent', value={keyId=<value>, keyAttribute=<value>}}
{type='device', id=<id>, property='accessControlEvent', value=<value>}
{type='profile', property='activeProfile', value=<value>, old=<value>}
{type='custom-event', name=<name>}
{type='deviceEvent', id=<id>, value='removed'}
{type='deviceEvent', id=<id>, value='changedRoom'}
{type='deviceEvent', id=<id>, value='created'}
{type='deviceEvent', id=<id>, value='modified'}
{type='sceneEvent', id=<id>, value='started'}
{type='sceneEvent', id=<id>, value='finished'}
{type='sceneEvent', id=<id<, value='instance', instance=<number>}
{type='sceneEvent', id=<id>, value='removed'}
{type='sceneEvent', id=<id>, value='modified'}
{type='sceneEvent', id=<id>, value='created'}
{type='onlineEvent', value=<boolean>}
{type='room', id=<id>, value='created'}
{type='room', id=<id>, value='removed'}
{type='room', id=<id>, value='modified'}
{type='section', id=<id>, value='created'}
{type='section', id=<id>, value='removede'}
{type='section', id=<id>, value='modified'}
{type='location',id=<userid>,property=<locationid>,value=<geofenceaction>,timestamp=<number>}
{type='ClimateZone',...}
{type='ClimateZoneSetpoint',...}


Time subscription:
{type='cron', time=<cronString>, tag=<string>}

cron  string format:
"<min> <hour> <day> <month> <wday> <year>"

min:   0-59
hour:  0-23
day:   1-31
month: 1-12
wday:  1-7   1=sunday
year:  YYYY

Ex.
"0 * * * * *"                  Every hour
"0/15 * * * * *"               Every 15 minutes
"0,20 * * * * *"               At even hour and 20min past
"0 * * 1-3 * *"                Every hour, January to March
"0 7 lastw-last * 1 *"         7:00, every sunday in the last week of the month
"sunset -10 lastw-last * 1 *"  10min before sunset every sunday in the last week of the month
--]]

--%%name="TriggerQA"
--%%type="com.fibaro.deviceController"

--FILE:lib/fibaroExtra.lua,fibaroExtra;
----------- Code -----------------------------------------------------------

if hc3_emulator then hc3_emulator.installQA{file="test/trigger.lua"} end

local VERSION = 1.23
local SERIAL = "UPD896661234567895"

local TRIGGER_VAR = 'TRIGGER_SUB'

local timers,addTimer,removeTimer = {}
local equal

local function notify(id,env)
  local event = env.event
  event._trigger = nil
  quickApp:debugf("Notifying QA:%s - %s",id,json.encode(event))
  fibaro.call(id,"sourceTrigger",event)
end

-- {type='time', value=<date string>, tag=<tag>}
-- { <date string> -> { fun, {id, tag } }

local idSubs = {}
local function updateSubscriber(id,events)
  quickApp:debugf("Updating subscriptions for QA:%s",id)
  removeTimer(id)
  for _,s in ipairs(idSubs[id] or {}) do
    fibaro.removeEvent(s.event,s.fun)
  end
  idSubs[id]={}
  for _,e in ipairs(events) do
    if e.type == 'cron' then
      local stat,res = pcall(addTimer,id,e.time,e.tag)
      if not stat then
        quickApp:errorf("updateSubscriber %s - %s (cron:%s)",id,tostring(e.time),res)
      end
    else
      local flag = true
      for _,ev in ipairs(idSubs[id]) do 
        if equal(ev.event,e) then flag = false; break end
      end
      if flag then
        local function fun(ev) notify(id,ev) end
        idSubs[id][#idSubs[id]+1]={event=e,fun=fun}
        local stat,res = pcall(function()
            fibaro.event(e,fun)
            fibaro.enableSourceTriggers(e.type,true) 
          end)
        if not stat then quickApp:errorf("updateSubscriber %s - %s",id,res) end
      end
    end
  end
end

local function checkVars(id,vars)
  for _,var in ipairs(vars or {}) do 
    if var.name==TRIGGER_VAR then updateSubscriber(id,var.value) end
  end
end

local function timer()
  local nxt = (1+ os.time() // 60) * 60
  local function loop()
    local t = os.date("*t")
    for s,d in pairs(timers) do  -- { <timeStr>, test=<fun>, ids={id=tag, ... } }
      if d.test(t) then
        for id,tag in pairs(d.ids) do notify(id,{event={type='time', value=s, tag=tag}}) end
      end
    end
    nxt = nxt+60
    setTimeout(loop,1000*(nxt-os.time()))
  end
  setTimeout(loop,1000*(nxt-os.time()))
end

function addTimer(id,timeStr,tag)
  local d = timers[timeStr]
  tag = tag or true
  if d then d.ids[id]=tag 
  else
    timers[timeStr]={ test=fibaro.dateTest(timeStr), ids={[id]=tag}} 
  end
end

function removeTimer(id)
  for s,d in pairs(timers) do
    d.ids[id]=nil
    if next(d.ids)==nil then timers[s]=nil end
  end
end

function QuickApp:onInit()
  equal = fibaro.utils.equal
  self:debugf("%s deviceId:%s, v%s",self.name,self.id,VERSION)
  self:setVersion("TriggerQA",SERIAL,VERSION)
  fibaro._REFRESHSTATERATE = 10
  --fibaro.debugFlags._allRefreshStates = true -- log all incoming refrshState events
  fibaro.debugFlags.logTrigger=false -- Enable log source triggers (when log text for UI changes)
  fibaro.enableSourceTriggers({'quickvar','deviceEvent'},true) -- Get events of these types
  fibaro.activatedPartitionsEvents() -- Get alarm activated events

  -- At startup, check all QAs for subscriptions
  for _,d in ipairs(api.get("/devices?interface=quickApp") or {}) do
    checkVars(d.id,d.properties.quickAppVariables)
  end

  self:event({type='quickvar',name=TRIGGER_VAR},        -- If some QA changes subscription
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

  timer()
end

--[[ Subscription function for clients, or just set quickAppVariable 'TRIGGER_SUB'
function QuickApp:clearSubscriptions() self:setVariable('TRIGGER_SUB',{}) end
function QuickApp:subscribe(event)
  local s = self:getVariable('TRIGGER_SUB')
  if type(s)~='table' then s = {} end
  s[#s+1]=event
  self:setVariable('TRIGGER_SUB',s)
end
--]]