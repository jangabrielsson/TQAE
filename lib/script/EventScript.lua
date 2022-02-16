_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
}

--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:lib/script/parser.lua,parser;
--FILE:lib/script/eval.lua,eval;
local gstruct=true
g = {h=9}
function QuickApp:main()
--  rule("a = 8+9")
  ID = 99
--  rule("{88,66}:bar & 10:00..11:00 => 77")
--  rule("$A")
--  rule("$A = 88")
 rule("setp a,$b,g.foo=8,9,10")
  --rule("$fopp.foo")
end

local parser = makeParser()
local compiler = makeCompiler()
local fmt = string.format

local function eval(expr) return (compiler.compile(expr))() end
local function tstr(e) return tostring(e) end
local function fstr(e) return tonumber(e) end

local getTriggers

local function addTrigger(tab,id,prop)
  id=tstr(id)
  tab[id] = tab[id] or {}
  tab[id][prop]=true
end

local trigC = {
  ['getprop'] = function(e,trs) 
    local ids=eval(e[2])
    if type(ids)=='table' then
      for _,id in ipairs(ids) do addTrigger(trs.trigger,id,e[3]) end
    elseif type(ids)=='number' then
      addTrigger(trs.trigger,ids,e[3])
    elseif type(ids)=='userdata' and ids._PROP then
    end
    getTriggers(e[2],trs)
  end,
  ['setprop'] = function(e,trs)
    local ids=eval(e[2])
    if type(ids)=='table' then
      for _,id in ipairs(ids) do addTrigger(trs.trigger,id,e[3]) end
    elseif type(ids)=='number' then
      addTrigger(trs.trigger,ids,e[3])
    elseif type(ids)=='userdata' and ids._PROP then
    end
    getTriggers(e[2],trs)
    getTriggers(e[3],trs)
  end,
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

local getArg = compiler.hooks.getArg
local instr={}

function instr.getprop(i,st,env) st.push(props[i[2]](getArg(i[3],st))) end
function instr.setprop(i,st,env) st.push(props[i[2]](getArg(i[3],st))) end

instr['..']= function (i,st,env)
  local t2,t1=st.pop(),st.pop()
  local n = now()
  if t1 <= n and n <= t2 then st.push(true)
  elseif t1 > t2 and n <= t1 and n >= t2 then st.push(true)
  else st.push(false) end
end

instr['##'] = function(i,st,env) st.push(#st.pop()) end
instr['@'] = function(i,st,env) st.push(st.pop()) end
instr['@@'] = function(i,st,env) st.push(st.pop()) end

for i,f in pairs(instr) do compiler.hooks.addInstr(i,f) end

function rule(str)
  local p,isRule = parser(str)
  if gstruct then print(json.encode(p)) end
  f = compiler.compile(p,dump)
  if not isRule  then 
    local res = {f()}
    for i=1,#res  do res[i]=tostring(res[i]) end
    quickApp:tracef("%s, = %s",str,table.concat(res,","))
  else
    local h = p[2]
    local triggers = getTriggers(h,{daily={},interv={},trigger={}})
    print(json.encode(triggers))
  end
end

function QuickApp:onInit()
  if self.main then self:main() end
end