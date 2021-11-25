-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator
_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { 
    onAction=true, http=false, UIEevent=true 
  },
}

--%%name="TriggerQA"
--%%type="com.fibaro.deviceController"

--FILE:lib/fibaroExtra.lua,fibaroExtra;
----------- Code -----------------------------------------------------------

--if hc3_emulator then hc3_emulator.loadQA("triggerTest.lua"):install() end

local VERSION = 1.20
local SERIAL = "UPD896661234567895"

local TRIGGER_VAR = 'TRIGGER_SUB'

local function notify(id,env)
  quickApp:debugf("Notifying QA:%s",id)
  local event = env.event
  event._trigger = nil
  fibaro.call(id,"sourceTrigger",event)
end

local idSubs = {}
local function updateSubscriber(id,events)
  quickApp:debugf("Updating subscriptions for QA:%s",id)
  for _,s in ipairs(idSubs[id] or {}) do
    fibaro.removeEvent(s.event,s.fun)
  end
  idSubs[id]={}
  for _,e in ipairs(events) do
    local function fun(ev) notify(id,ev) end
    idSubs[id][#idSubs[id]+1]={event=e,fun=fun}
    local stat,res = pcall(function()
        fibaro.event(e,fun)
        fibaro.enableSourceTriggers(e.type,true) 
      end)
    if not stat then quickApp:errorf("updateSubscriber %s - %s",id,res) end
  end
end

local function checkVars(id,vars)
  for _,var in ipairs(vars or {}) do 
    if var.name==TRIGGER_VAR then updateSubscriber(id,var.value) end
  end
end

function QuickApp:onInit()
  self:debugf("%s deviceId:%s, v%s",self.name,self.id,VERSION)
  self:setVersion("TriggerQA",SERIAL,VERSION)
  fibaro._REFRESHSTATERATE = 10
  fibaro.enableSourceTriggers({'quickvar','deviceEvent'},true) -- Get events of these types

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
    function(env)                                             -- update
      local id = env.event.id
      if id ~= self.id then
        checkVars(id,api.get("/devices/"..id).properties.quickAppVariables)
      end
    end)
end

--[[ Subscription function for clients, or just set quickAppVariable 'TRIGGER_SUB'
function QuickApp:subscribe(event)
  local s = self:getVariable('TRIGGER_SUB')
  if s == nil or s == "" then s = {} end
  s[#s+1]=event
  self:setVariable('TRIGGER_SUB',s)
end
--]]