_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
}

--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:lib/script/parser.lua,parser;
--FILE:lib/script/eval.lua,eval;
--FILE:lib/script/EventScriptFuns.lua,funs;
--FILE:lib/script/EventScript.lua,ES;

local rule
--local g_struct = true
--local g_dump   = true
--local g_trace  = true 

_MARSHALL = true
local fmt = string.format
local function printf(f,...) print(fmt(f,...)) end

function QuickApp:main()
  EVENTSCRIPT.addPropHandler('bar',
    {method=function(id,prop) return type(id)..":"..id end, prop='bar',  table=false, trigger=true},
    {method=function(id,prop,val) return type(id)..":"..id end,p='bar'}
  )
  function fibaro.now() return os.time()-fibaro.midnight() end
  x = 10
  g = {h=9}
  function foo(...) local  a = {...} return a[1]+a[2] end
  ID = 88

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
    {5,"g=ID:bar",{},{"number:88"}}, 
    {5.1,"g=44:bar",{},{"number:44"}},
    {5.12,"g={44}:bar",{},{{"number:44"}}}, 
    {5.13,"ID:bar",{},{"number:88"}}, 
    {5.14,"44:bar",{},{"number:44"}}, 
    {5.15,"{44}:bar",{},{{"number:44"}}},  
    {5.16,"44:bar=77",{},{77}},
    {6.1,"a = now-1..now+2",{},{true}},  
    {7.1,"a = true & false",{},{false}},
    {8.1,"$A=99",{},{99}}, 
    {8.2,"a = $A",{},{99}},    
    {8.2,"a = now",{},{fibaro.now()}},
    {8.2,"a = midnight",{},{fibaro.midnight()}},   
    {10,"true => a=66",{},{66}}, 
    {10.1,"@10:00 => a=66",{},{66}},
    {10.2,"@{10:00,22:00} => a=66",{},{66}},  
    {10.3,"@@10:00 => a=66",{},{66}},
    {20,"true => 66:bar; 77:bar",{},{"number:42"}},
    {20.1,"true => true & true & true",{},{true}},
    {20.2,"true => true & true & false",{},{false}},
    {20.3,"true => true & true & a=9",{},{9}},
  }

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
    local tag,expr,args,res,dumpcode,trace,dumpstruct = e[1],e[2],e[3],e[4],e[5] or g_dump,e[6] or g_trace, e[7] or g_struct
    local t = os.clock()
    local r = {rule(expr,{trace=trace,dumpstruct=dumpstruct,dumpcode=dumpcode})}
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

--for _,e in ipairs(tests) do runTest(e) end
  runTests()
end

function QuickApp:onInit()
  EVENTSCRIPT.setupES()
  rule = EVENTSCRIPT.rule
  self:main()
end