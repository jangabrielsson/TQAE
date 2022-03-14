_=loadfile and loadfile("TQAE.lua"){
  --refreshStates=true,
  debug = { webserver = true },
  copas=true,
  shadow=true
  --speed=48,
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
api.post("/globalVariables",{name='T',value='16:00'})

function QuickApp:main()
  --fibaro.debugFlags.post=true

  EVENTSCRIPT.addPropHandler('bar',
    {method=function(id,prop) return type(id)..":"..id end, prop='bar',  table=false, trigger=true},
    {method=function(id,prop,val) return type(id)..":"..id end,p='bar'}
  )
  function fibaro.now() return os.time()-fibaro.midnight() end
  x = 10
  g = {h=9}
  function foo(...) local  a = {...} return a[1]+a[2] end
  ID = 88

  EVENTSCRIPT.defTriggerVar("V")

  local function describe(str) print("\n"..rule(str).describe()) end
--  describe("!44:value & 10:00..14:00 => log('X')")
--  describe("@{10:00,$T} => log('X')")
--  describe("@00:05 & ID:bar => log('X')")
--  describe("@@00:05 & ID:bar => log('X')")
--  describe("@{catch,22:00} & ID:bar => log('X')")
--  describe("#foo & 10:00..15:00 => log('X')")
--  describe("ID:bar => log('X')")

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
    {8.3,"a = now",{},{fibaro.now()}},
    {8.4,"a = t/10:00",{},{fibaro.midnight()+3600*10}}, 
    {8.5,"a = n/10:00",{},{fibaro.midnight()+3600*10+24*3600}},  
    {8.6,"a = +/10:00",{},{os.time()+3600*10}},  
    {8.7,"a = midnight",{},{fibaro.midnight()}},  
    {10,"true => a=66",{},{66}}, 
    {10.1,"@10:00 => a=66",{},{66}},
    {10.2,"@{10:00,22:00} => a=66",{},{66}},
    {10.22,"@{catch,10:00} => a=66",{},{66}},  
    {10.3,"@@10:00 => a=66",{},{66}},
    {20,"@now => 66:bar; 77:bar",{},{"number:77"}},
    {20.1,"@now => true & true & true",{},{true}},
    {20.2,"@now => true & true & false",{},{false}},
    {20.3,"@now => true & true & a=9",{},{9}},
    {20.4,"77:bar => env.event.value",{},{88},nil,{type='device', id=77, property='bar', value=88}},    
    {20.5,"@@-00:00:05 => 88",{},{88}},
    {20.6,"#foo{val='$a'} => env.p.a",{},{22},nil,{type='foo',val=22}},
    {20.7,"add({6},77)",{},{{6,77}},nil},    
    {20.8,"V => V",{},{88},nil},
    {20.8,"V = 88; fopp(); S1.click",{},{16},nil},
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

  local function encode(e)
    if type(e)=='table' then
      if e.__tostring then return e:__tostring()  else
        local r = {}
        for _,v in ipairs(e) do r[#r+1]=encode(v) end
        return json.encode(r)
      end
    else return e end
  end
  local function pres(n,correct,r0,r1,t)
    printf("%05.2f:%s %-36s => %-20s %.2fms",n,correct and "OK" or  "NO",(encode(r0)):sub(2,-2),(encode(r1)):sub(2,-2),t)
  end

  local function runTest(e)
    local tag,expr,args,res = e[1],e[2],e[3],e[4]
    local la = e[5] or {}
    local dumpcode,trace,dumpstruct = la.c or g_dump, la.t or g_trace, la.s or g_struct
    local event = e[6]
    local t = os.clock()
    local function checkRes(_,...)
      local r = {...}
      if equal(r,res) then
        pres(tag,true,r,res,os.clock()-t)
      else
        pres(tag,false,r,res,os.clock()-t)
      end
      return ...
    end
    if expr:match("=>") then
      rule(expr,{trace=trace,dumpstruct=dumpstruct,dumpcode=dumpcode,bodyFun=checkRes})
      if event then fibaro.post(event) end
    else
      checkRes(rule(expr,{trace=trace,dumpstruct=dumpstruct,dumpcode=dumpcode}))
    end
  end

  local function runTests(n)
    for _,e in ipairs(tests) do
      if n==nil or e[1]==n then runTest(e) end
    end
    printf("Done")
  end

--for _,e in ipairs(tests) do runTest(e) end
  runTests(20.8)
end

function QuickApp:onInit()
  EVENTSCRIPT.setupES()
  rule = EVENTSCRIPT.rule
  self:main()
end