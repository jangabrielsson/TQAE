
EVENTSCRIPT = EVENTSCRIPT or {}
local function setupES()
  local parser = EVENTSCRIPT.makeParser()
  local compiler = EVENTSCRIPT.makeCompiler()
  EVENTSCRIPT.compiler = compiler
  EVENTSCRIPT.setupFuns()

  local fmt = string.format

  local function eval(expr) return (compiler.compile(expr))() end
  local function tstr(e) return tostring(e) end
  local function fstr(e) return tonumber(e) end
  local getTriggers

  local rules = {}
  local function createRule(nr,str,events)
    local r = {}
    local _str = fmt("Rule:%s %s",nr,str:sub(1,40))
    function r.__tostring() return _str  end
    function r.enable() end
    function r.disable() end
    function r.start() end
    rules[nr]=r
    return r
  end

  local function addTrigger(tab,typ,id,prop)
    id=tstr(id)
    tab[typ] = tab[typ] or {}
    tab[typ][id]=tab[typ][id] or {}
    tab[typ][id][prop]=true
  end

  local trigC = {
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
--  ['setglobal'] = function(e,trs) end,
    ['@'] = function(e,trs)
      local times = eval(e[2])
      if type(times) == 'table' then
        for _,t in ipairs(times) do trs.daily[tstr(t)]=true end
      elseif type(times)=='number' then
        trs.daily[tstr(times)]=true
      else error("@... expecting number") end
      getTriggers(e[2],trs)
    end,
    ['@@'] = function(e,trs) 
      local times = eval(e[2])
      if type(times) == 'table' then
        for _,t in ipairs(times) do trs.interv[tstr(t)]=true end
      elseif type(times)=='number' then
        trs.interv[tstr(times)]=true
      else error("@@... expecting number") end
      getTriggers(e[2],trs)
    end,
    ['table'] = function(e,trs)
      local t = eval(e)
      if t.type then
        trs.ev[#trs.ev+1]=t
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

  local nRules = 0
  local function rule(str,opts)
    opts = opts or {}
    local p,isRule = parser(str)
    if opts.dumpstruct then print(json.encode(p)) end
    f = compiler.compile(p,opts.dumpcode)
    compiler.trace(opts.trace)
    if not isRule  then 
      local res,res2 = {f()},{}
      for i=1,#res  do res2[i]=tostring(res[i]) end
      quickApp:tracef("%s, = %s",str,table.concat(res2,","))
      return table.unpack(res)
    else
      nRules = nRules+1
      local h = p[2]
      local triggers = getTriggers(h,{daily={},interv={},trigger={}})
      local daily,interv,events={},{},{}
      for d,_ in pairs(triggers.daily) do daily[#daily+1]=fstr(d) end
      for i,_ in pairs(triggers.interv) do interv[#interv+1]=fstr(i) end
      assert(not (#daily>0 and #interv>0),"Can't have both @ and @@ in same rule")
      for typ,r1 in pairs(triggers.trigger) do
        for id,r2 in pairs(r1) do
          for prop,_ in pairs(r2) do events[#events+1]=makeEvent(typ,id,prop) end
        end
      end
      rules = {}
      if #daily>0 then
        for _,t in ipairs(daily) do -- {daily=id}
          rules[#rules+1] = fibaro.event({type='daily',  rule=nRules},f)
        end
      elseif #interv>0 then
      elseif #events>0 then
      else error("No triggers in rule") end
    end
    return createRule(nRules,str,events)
  end
  EVENTSCRIPT.rule=rule
end

EVENTSCRIPT.setupES = setupES