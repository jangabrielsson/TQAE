--luacheck: globals ignore fibaro json quickApp
--luacheck: ignore 212/self
--luacheck: ignore 432/self

EVENTSCRIPT = EVENTSCRIPT or {}
EVENTSCRIPT.VERSION,EVENTSCRIPT.FIX = 0.6,"fix01"

--[[ Supported events:

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
{type='device', id=<id>, property='sceneACtivationEvent', value=<value>}
{type='profile', property='activeProfile', value=<value>, old=<value>}
{type='custom-event', name=<name>}
{type='updateReadyEvent', value=_}
{type='deviceEvent', id=<id>, value='removed'}
{type='deviceEvent', id=<id>, value='changedRoom'}
{type='deviceEvent', id=<id>, value='created'}
{type='deviceEvent', id=<id>, value='modified'}
{type='deviceEvent', id=<id>, value='crashed', error=<string>}
{type='sceneEvent',  id=<id>, value='started'}
{type='sceneEvent',  id=<id>, value='finished'}
{type='sceneEvent',  id=<id>, value='instance', instance=d}
{type='sceneEvent',  id=<id>, value='removed'}
{type='onlineEvent', value=<bool>}
{type='location', property='id', id=<number>, value=<string>}
{type='se-start', property='start', value='true'}
{type='climate', ...}
    
    New functions:
    self:profileId(name)                      -- returns id of profile with name
    self:profileName(id)                      -- returns name of profile with id
    self:activeProfile([id])                  -- activates profile id. If id==nil return active profile. 
    self:getCustomEvent(name)                 -- return userDescription field of customEvent
    self:postCustomEvent(name[,descr])        -- post existing customEvent (descr==nil), or creates and post customEvent (descr~=nil)
    http.get(url,options)                     -- syncronous versions of http commands, only inside eventscript
    http.put(url,options,data)                --
    http.post(url,options,data)               --
    http.delete(url,options)
--]]

local function setupES()
  local parser = EVENTSCRIPT.makeParser()
  local compiler = EVENTSCRIPT.makeCompiler()
  EVENTSCRIPT.compiler = compiler
  EVENTSCRIPT.setupFuns()

  local fmt,gLocals = string.format

  local vars = {}
  local triggerVars = {}
  local reverseVarTable = {}
  local function defvar(var,expr) if vars[var] then vars[var][1]=expr else vars[var]={expr} end end
  local function defvars(tab) for var,val in pairs(tab) do defvar(var,val) end end
  local function defTriggerVar(var,expr) triggerVars[var]=true; defvar(var,expr) end
  local function isTriggerVar(v) return triggerVars[v] end
  local function reverseMapDef(table) reverseMap({},table) end
  local function reverseMap(path,value)
    if type(value) == 'number' then reverseVarTable[tostring(value)] = table.concat(path,".")
    elseif type(value) == 'table' and not value[1] then
      for k,v in pairs(value) do table.insert(path,k); reverseMap(path,v); table.remove(path) end
    end
  end
  local function reverseVar(id) return reverseVarTable[tostring(id)] or id end

  local function getVar(n) if vars[n] then return vars[n][1] else return _G[n] end end
  local function setVar(n,v)
    local oldref=vars[n]
    local oldval=oldref[1]
    if oldref then oldref[1] = v else vars[n]={v} end
    if isTriggerVar(n) and oldval and oldval[1]~=v or oldval==nil then fibaro.post({type='%triggervar',name=n, value=v}) end
  end
  EVENTSCRIPT.defvar,EVENTSCRIPT.defvars = defvar,defvars
  EVENTSCRIPT.defTriggerVar,EVENTSCRIPT.reverseMapDef = defTriggerVar,reverseMapDef

  compiler.hooks.globalLuaVar.get = getVar
  compiler.hooks.globalLuaVar.set = setVar

  local function eval(expr)
    local f = compiler.compile(expr,{locals=gLocals})
    return f() 
  end
  local function tstr(e) return tostring(e) end
  local function fstr(e) return tonumber(e) end
  local function now() return os.time() - fibaro.midnight() end
  local getTriggers

  local rules = {}
  local function createRule(nr,str,event,doc)
    local r = {}
    function r.__tostring() return doc  end
    function r.enable() return event.enable() end
    function r.disable() return event.disable() end
    function r.start() return event.start() end
    function r.describe() return tostring(event) end
    rules[nr]=r
    return r
  end

  local function addTrigger(tab,typ,id,prop)
    id=tstr(id)
    tab[typ] = tab[typ] or {}
    tab[typ][id]=tab[typ][id] or {}
    tab[typ][id][prop]=true
  end

  local trigC
  trigC = {
    ['getprop'] = function(e,trs)
      local ids,prop=eval(e[2]),e[3]
      if type(ids)=='table' then
        for _,id in ipairs(ids) do addTrigger(trs.trigger,'device',id,prop) end
      elseif type(ids)=='number' then
        addTrigger(trs.trigger,'device',ids,prop)
      elseif type(ids)=='userdata' and ids._PROP then
      end
      getTriggers(e[2],trs)
    end,
    ['getglobal'] = function(e,trs) 
      addTrigger(trs.trigger,'global-variable',e[2],'value')
    end,
    ['var'] = function(e,trs)
      if isTriggerVar(e[2]) then
        trs.ev[#trs.ev+1]={type='%triggervar',name=e[2]}
      end
    end,
--  ['setglobal'] = function(e,trs) end,
    ['daily'] = function(e,trs)
      local times = eval(e[2])
      trs.dailyFlag = true
      if type(times) == 'table' then
        for _,t in ipairs(times) do trs.daily[tstr(t)]=true end
      elseif type(times)=='number' then
        trs.daily[tstr(times)]=true
      else error("@... expecting number") end
      trs.dailyTriggers = {daily={},interv={},trigger={},ev={}}
      getTriggers(e[2],trs.dailyTriggers)
    end,
    ['interv'] = function(e,trs) 
      local times = eval(e[2])
      if type(times) == 'table' then
        for _,t in ipairs(times) do trs.interv[tstr(t)]=true end
      elseif type(times)=='number' then
        trs.interv[tstr(times)]=true
      else error("@@... expecting number") end
      getTriggers(e[2],trs)
    end,
    ['quote'] = function(e,trs)
      local t = e[2]
      if type(t)=='table' and t.type then
        e[1],e[2]='match_event',{'quote',t}
        trs.ev[#trs.ev+1]=t
      end
    end,
    ['table'] = function(e,trs)
      local t = eval(e)
      if type(t)=='table' and t.type then
        e[1],e[2],e[3]='match_event',{'quote',t},nil
        trs.ev[#trs.ev+1]=t
      end
      local i = 2
      while i <= #e do
        if e[i]=="__KEY_" then i=i+1
        else getTriggers(e[i],trs) end
        i=i+1
      end
    end,
    ['betw'] = function(e,trs) 
      local s1,s2=eval(e[2]),eval(e[3])
      trs.daily[tstr(s1)],trs.daily[tstr(s2+1)]=true,true
      getTriggers(e[2],trs)
      getTriggers(e[3],trs)
    end,
  }

  function getTriggers(expr,trs)
    if type(expr) == 'table' then
      if trigC[expr[1] or ""] then trigC[expr[1] or ""](expr,trs)
      else
        for i=2,#expr do getTriggers(expr[i],trs) end
      end
    end
    return trs
  end

  local function makeEvent(typ,id,prop,vs)
    if typ=='device' then return {type='device', id = tonumber(id), property=prop}
    elseif typ=='global-variable' then return {type='global-variable', name = id}
    else return vs end
  end

  local function createTriggers(trs)
    local events = {}
    for typ,r1 in pairs(trs) do
      for id,r2 in pairs(r1) do
        for prop,_ in pairs(r2) do events[#events+1]=makeEvent(typ,id,prop) end
      end
    end
    return events
  end

  local nRules = 0
  local function rule(str,opts)
    opts = opts or {}
    local catch = math.maxinteger
    gLocals = { catch = {catch} }
    local p,isRule = parser(str)
    if opts.dumpstruct then print(json.encode(p)) end
    compiler.trace(opts.trace)

    if not isRule  then
      local f,env = compiler.compile(p,{dump=opts.dumpcode,locals=gLocals})
      local function rf(e) env.env = e return f(e) end
      env.headerFun,env.bodyFun = opts.headerFun,opts.bodyFun
      local res,res2 = {rf()},{}
      for i=1,#res  do res2[i]=tostring(res[i]) end
      quickApp:tracef("%s, = %s",str,table.concat(res2,","))
      return table.unpack(res)

    else
      nRules = nRules+1
      local h = p[2]
      local doc = fmt("Rule:%s %s",nRules,str:sub(1,40))
      local f,env = compiler.compile(p,{dump=opts.dumpcode,locals=gLocals})
      local triggers = getTriggers(h,{daily={},interv={},trigger={},ev={}})
      local function rf(e) env.env = e return f(e) end
      env.headerFun,env.bodyFun = opts.headerFun,opts.bodyFun
      local daily,interv,events={},{}
      for d,_ in pairs(triggers.daily) do daily[#daily+1]=fstr(d) end
      for i,_ in pairs(triggers.interv) do interv[#interv+1]=fstr(i) end
      assert(not (#daily>0 and #interv>0),"Can't have both @ and @@ in same rule")
      events = createTriggers(triggers.trigger)
      for _,e in ipairs(triggers.ev) do events[#events+1]=e end
      local catch = table.delete(daily,catch)
      if #daily > 0 then
        if triggers.dailyFlag then
          events = createTriggers(triggers.dailyTriggers.trigger)
        end
        events[#events+1]={type='%daily', rule=nRules}
        fibaro.post({type='%daily', rule=nRules, now=now(), catch=catch, _sh=true})
      elseif #interv>0 then
        events = {{type='%interv', rule=nRules}}
        local t = 0
        if interv[1] < 0 then
          t = -interv[1]
          t = (os.time() // t) * t + t - os.time()
        end
        fibaro.post({type='%interv', rule=nRules, nxt=os.time()+t, _sh=true},t)
      elseif #events < 1 then
        error("No triggers in rule")  
      end
      local event = fibaro.event(events,rf,doc)
      return createRule(nRules,str,event,doc)
    end
  end
  EVENTSCRIPT.rule=rule

  local S1 = {click = 16, double = 14, tripple = 15, hold = 12, release = 13}
  local S2 = {click = 26, double = 24, tripple = 25, hold = 22, release = 23} 

  defvar('S1',S1)
  defvar('S2',S2)
  defvar('catch',math.huge)
  defvar("defvars",defvars)
  defvar("mapvars",reverseMapDef)
  defvar("print",function(...) quickApp:printTagAndColor(...) end)
  defvar("QA",quickApp)
  defvar("fopp",function() print("foo") end)
end

EVENTSCRIPT.setupES = setupES