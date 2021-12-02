-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator
_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { 
    onAction=true, http=false, UIEevent=true 
  },
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
"0 * * * * *"           Every hour
"0/15 * * * * *"        Every 15 minutes
"0,20 * * * * *"        At even hour and 20min past
"0 * * 1-3 * *"         Every hour, January to March
"0 7 lastw-last * 1 *"  7:00, every sunday in the last week of the month
--]]

--%%name="TriggerQA"
--%%type="com.fibaro.deviceController"

--FILE:lib/fibaroExtra.lua,fibaroExtra;
----------- Code -----------------------------------------------------------

if hc3_emulator then hc3_emulator.installQA{file="test/testE.lua"} end

local VERSION = 1.21
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

local function cronTest(dateStr) -- code for creating cron date test to use in scene condition
  local days = {sun=1,mon=2,tue=3,wed=4,thu=5,fri=6,sat=7}
  local months = {jan=1,feb=2,mar=3,apr=4,may=5,jun=6,jul=7,aug=8,sep=9,oct=10,nov=11,dec=12}
  local last,month = {31,28,31,30,31,30,31,31,30,31,30,31},nil

  local function seq2map(seq) local s = {} for _,v in ipairs(seq) do s[v] = true end return s; end

  local function flatten(seq,res) -- flattens a table of tables
    res = res or {}
    if type(seq) == 'table' then for _,v1 in ipairs(seq) do flatten(v1,res) end else res[#res+1] = seq end
    return res
  end

  local function expandDate(w1,md)
    local function resolve(id)
      local res
      if id == 'last' then month = md res=last[md]
      elseif id == 'lastw' then month = md res=last[md]-6
      else res= type(id) == 'number' and id or days[id] or months[id] or tonumber(id) end
      if res==nil then error("Bad date specifier "..tostring(id)) end 
      return res
    end
    local w,m,step= w1[1],w1[2],1
    local start,stop = w:match("(%w+)%p(%w+)")
    if (start == nil) then return resolve(w) end
    start,stop = resolve(start), resolve(stop)
    local res,res2 = {},{}
    if w:find("/") then
      if not w:find("-") then -- 10/2
        step=stop; stop = m.max
      else step=w:match("/(%d+)") end
    end
    step = tonumber(step)
    assert(start>=m.min and start<=m.max and stop>=m.min and stop<=m.max,"illegal date interval")
    while (start ~= stop) do -- 10-2
      res[#res+1] = start
      start = start+1; 
      if start>m.max then start=m.min end
    end
    res[#res+1] = stop
    if step > 1 then 
      for i=1,#res,step do res2[#res2+1]=res[i] end
      res=res2 
    end
    return res
  end

  table.maxn = table.maxn or function(t) return #t end

  local function map(f,l,s) s = s or 1; local r={} for i=s,table.maxn(l) do r[#r+1] = f(l[i]) end return r end
  local function parseDateStr(dateStr,last)
    local seq = dateStr:split(" ")   -- min,hour,day,month,wday
    local lim = {{min=0,max=59},{min=0,max=23},{min=1,max=31},{min=1,max=12},{min=1,max=7},{min=2019,max=2030}}
    for i=1,6 do if seq[i]=='*' or seq[i]==nil then seq[i]=tostring(lim[i].min).."-"..lim[i].max end end
    seq = map(function(w) return w:split(",") end, seq)   -- split sequences "3,4"
    local month = os.date("*t",os.time()).month
    seq = map(function(t) local m = table.remove(lim,1);
        return flatten(map(function (g) return expandDate({g,m},month) end, t))
      end, seq) -- expand intervals "3-5"
    return map(seq2map,seq)
  end
  local sun,offs,day,sunPatch = dateStr:match("^(sun%a+) ([%+%-]?%d+)")
  if sun then
    sun = sun.."Hour"
    dateStr=dateStr:gsub("sun%a+ [%+%-]?%d+","0 0")
    sunPatch=function(dateSeq)
      local h,m = (fibaro.getValue(1,sun)):match("(%d%d):(%d%d)")
      dateSeq[1]={[(h*60+m+offs)%60]=true}
      dateSeq[2]={[math.floor((h*60+m+offs)/60)]=true}
    end
  end
  local dateSeq = parseDateStr(dateStr)
  return function(ctx) -- Pretty efficient way of testing dates...
    local t = ctx or os.date("*t",os.time())
    if month and month~=t.month then parseDateStr(dateStr) end -- Recalculate 'last' every month
    if sunPatch and (month and month~=t.month or day~=t.day) then sunPatch(dateSeq) day=t.day end -- Recalculate 'last' every month
    return
    dateSeq[1][t.min] and    -- min     0-59
    dateSeq[2][t.hour] and   -- hour    0-23
    dateSeq[3][t.day] and    -- day     1-31
    dateSeq[4][t.month] and  -- month   1-12
    dateSeq[5][t.wday] or false      -- wekday 1-7, 1=sun, 7=sat
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
    timers[timeStr]={ test=cronTest(timeStr), ids={[id]=tag}}
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
function QuickApp:clearSubscriptions() self:setVariable('TRIGGER_SUB',{})
function QuickApp:subscribe(event)
  local s = self:getVariable('TRIGGER_SUB')
  if type(s)~='table' then s = {} end
  s[#s+1]=event
  self:setVariable('TRIGGER_SUB',s)
end
--]]