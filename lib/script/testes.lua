dofile("lib/json.lua")
dofile("lib/script/eval.lua")
dofile("lib/script/parser.lua")

local gdump = true
--local gtrace = true
local gstruct = true

function foo(...) local  a = {...} return a[1]+a[2] end
ID = 88

-- a=#event
-- HH:MM:SS
-- foo:prop
-- 88:prop

local tests = {
  {1,"a = 9",{},{9}},
  {1.1,"a = 9+2*3",{},{15}},
  {1.2,"a=00:15",{},{15*60}},
  {1.3,"a=01:15",{},{3600*1+15*60}},
  {1.4,"a=01:15:04",{},{3600*1+15*60+4}},
  {1.5,"a = 9; b=10; c=a+b*2",{},{29}},
  {2,"a={}",{},{{}}},
  {2.2,"a={3,4,5}",{},{{3,4,5}}},
  {2.21,"{3,4,5}",{},{{3,4,5}}},
  {2.3,"a={a=9,b=5}",{},{{a=9,b=5}}},
  {2.4,"a={a=9,b=5}; a['a']=10; return a",{},{{a=10,b=5}}},
  {2.5,"a={a=9,b=5}; a.a=10; return a",{},{{a=10,b=5}}},
  {2.55,"b={4,5}; b[8] = 54",{},{54}},
  {2.6,"a=#foo",{},{{type="foo"}}},
  {2.61,"#foo",{},{{type="foo"}}},
  {2.7,"a=#foo{y=9}",{},{{type="foo",y=9}}},
  {2.8,"b=11; a=#foo{y=b}",{},{{type="foo",y=11}}},
  {3,"local y=0; for x=1,3 do y=y+x end; return y",{7},{6}},
  {4,"foo(8,7)",{},{15}},
  {5,"g=ID:bar",{},{"number:42"}}, 
  {5.1,"g=44:bar",{},{"number:42"}},
  {5.12,"g={44}:bar",{},{"table:42"}}, 
  {5.13,"ID:bar",{},{"number:42"}}, 
  {5.14,"44:bar",{},{"number:42"}}, 
  {5.15,"{44}:bar",{},{"table:42"}},  
  {5.16,"44:bar=77",{},{"table:42"}},
  {6.1,"a = 07:00..10:00",{},{false}},  
  {7.1,"a = true & false",{},{false}},
  {8.1,"a = $barf",{},{false}},   
  {10,"true => a=66",{},{66}}, 
  {10.1,"@10:00 => a=66",{},{66}},
  {10.2,"@{10:00,22:00} => a=66",{},{66}},  
  {10.3,"@@10:00 => a=66",{},{66}},
  {20,"true => 66:bar; 77:bar",{},{"number:42"}},
  {20.1,"true => true & true & true",{},{true}},
  {20.2,"true => true & true & false",{},{false}},
  {20.3,"true => true & true & a=9",{},{9}},
}

local parser = makeParser()
local compiler = makeCompiler()
local fmt = string.format

local function printf(f,...) print(fmt(f,...)) end

local function equal(e1,e2)
  if e1==e2 then return true
  else
    if type(e1) ~= 'table' or type(e2) ~= 'table' then return false
    else
      for k1,v1 in pairs(e1) do if e2[k1] == nil or not equal(v1,e2[k1]) then return false end end
      for k2,_  in pairs(e2) do if e1[k2] == nil then return false end end
      return true
    end
  end
end

local function pres(n,correct,r0,r1,t)
  printf("%05.2f:%s %-36s => %-20s %.2fms",n,correct and "OK" or  "NO",(json.encode(r0)):sub(2,-2),(json.encode(r1)):sub(2,-2),t)
end

local function runTest(e)
  local tag,expr,args,res,dump,trace = e[1],e[2],e[3],e[4],e[5] or gdump,e[6] or gtrace
  local p = parser(expr)
  if gstruct then print(json.encode(p)) end
  f = compiler.compile(p,dump)
  compiler.trace(trace)
  local t = os.clock()
  local r = {f(table.unpack(args))}
  if equal(r,res) then
    pres(tag,true,r,res,os.clock()-t)
  else
    pres(tag,false,r,res,os.clock()-t)
  end
end

local function runTests(n)
  for _,e in ipairs(tests) do
    if n==nil or e[1]==n then runTest(e) end
  end
end

function compiler.hooks.optimizeCode(code)
  for _,e in ipairs(code) do
    if e[1]=='call0' and e[3]:match('^get_prop_') then
      e[1]='get_prop'
      e[3]=e[3]:match('get_prop_(.*)')
    end
  end
  return code
end

local props = {
  bar = function(id) return type(id)..":"..42 end
}

local function midnight() 
  local t = os.date("*t")
  return os.time()-t.sec-60*t.min-3600*t.hour
end

local function now() return os.time()-midnight() end

local getArg = compiler.hooks.getArg
compiler.hooks.addInstr('getprop',
  function (i,st,env)
    st.push(props[i[2]](getArg(i[3],st)))
  end
)
compiler.hooks.addInstr('setprop',
  function (i,st,env)
    st.push(props[i[2]](getArg(i[3],st)))
  end
)
compiler.hooks.addInstr('..',
  function (i,st,env)
    local t2,t1=st.pop(),st.pop()
    local n = now()
    if t1 <= n and n <= t2 then st.push(true)
    elseif t1 > t2 and n <= t1 and n >= t2 then st.push(true)
    else st.push(false) end
  end
)
compiler.hooks.addInstr('##',
  function (i,st,env) st.push(#st.pop()) end
)
compiler.hooks.addInstr('@',
  function (i,st,env) st.push(st.pop()) end
)
compiler.hooks.addInstr('@@',
  function (i,st,env) st.push(st.pop()) end
)
--for _,e in ipairs(tests) do runTest(e) end
runTests(8.1)