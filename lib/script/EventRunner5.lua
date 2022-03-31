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

--%%name="EventRunner"

function QuickApp:main()
  fibaro.debugFlags.post=true
  local rule,defvar,defvars = EVENTSCRIPT.rule,EVENTSCRIPT.defvar,EVENTSCRIPT.defvars
  local defTriggerVar,reverseMapDef = EVENTSCRIPT.defTriggerVar, EVENTSCRIPT.reverseMapDef
  local fmt = string.format

  local function encode(e)
    if type(e)=='table' then
      if e.__tostring then return e:__tostring()  else
        local r = {}
        for _,v in ipairs(e) do r[#r+1]=encode(v) end
        return table.concat(r,",")
      end
    else return tostring(e) end
  end

  local fmtStr = "%-40s %-20s %-20s"

  BSW = hc3_emulator.create.binarySwitch(1100,"BSW")
  MSW = hc3_emulator.create.multilevelSwitch(1101,"MSW")
  BSE = hc3_emulator.create.binarySensor(1102,"BSE")
  MSE = hc3_emulator.create.multilevelSensor(1103,"MSE")

  local TIMEOUT = 10000
  local tests,resHack={}
  local function check(env,...)
    local opts = env.opts
    if tests[opts.nr] then clearTimeout(tests[opts.nr]) tests[opts.nr]=nil end
    local res2 = {...}
    if opts.res2 then res2 = type(opts.res2)=='function' and opts.res2(res2) or opts.res2 end
    local r1,r2=encode(opts.res),encode(res2)
    if fibaro.utils.equal(opts.res,res2) then 
      if opts.logOK then quickApp:debugf(fmtStr,"'"..opts.doc:sub(1,35).."'",r1:sub(1,15),r2:sub(1,15)) end
    else quickApp:errorf(fmtStr,"'"..opts.doc:sub(1,35).."'",r1:sub(1,15),r2:sub(1,15)) end
    return ...
  end

  local function create(opts)
    tests[opts.nr]=setTimeout(function() tests[opts.nr]=nil; quickApp:errorf("rule %s timed out",opts.nr) end,TIMEOUT)
  end

  local function checkFib(...) return {resHack} end

  EVENTSCRIPT.fib = {}
  local DTypes,DTID={},2000
  function EVENTSCRIPT.fibaro.get(id,prop)
    if DTypes[id] then
      assert(DTypes[id].properties[prop]~=nil,fmt("Missing prop '%s' for device:%s",prop,id))
    end
    resHack = fmt([[fibaro.get(%s,"%s")]],id,prop)
    return fibaro.get(id,prop)
  end
  function EVENTSCRIPT.fibaro.call(id,method,...)
    if DTypes[id] then
      assert(DTypes[id].actions[method]~=nil,fmt("Missing action '%s' for device:%s",method,id))
    end
    local args = {...}
    resHack = fmt("fibaro.call(%s)",json.encode({id,method,table.unpack(args)}):sub(2,-2))
  end
  EVENTSCRIPT.fibaro.setup()

  local function DT(typ)
    local id = DTID; DTID=DTID+1
    DTypes[id]=hc3_emulator.EM.getDeviceResources()[typ]
    return id
  end

  EVENTSCRIPT.ruleOpts.bodyFun = check
  EVENTSCRIPT.ruleOpts.createFun = create
  EVENTSCRIPT.ruleOpts.logOK = true
  EVENTSCRIPT.ruleOpts.logRes = false

  defTriggerVar("T0")

--  rule("a = true & false",{res={false}})
--  rule("a = true or false",{res={true}})
--  rule("a = !false",{res={true}})
--  rule("a = 6 + 10",{res={16}})
--  rule("b = a + 10",{res={26}})
--  rule("-10",{res={-10}})
--  rule("-b+a",{res={-10}})
--  rule("round(10.2)",{res={10}})
--  rule("round(10.6)",{res={11}})
--  rule("sum(3,5,7)",{res={15}})
--  rule("sum({3,5,7})",{res={15}})
--  rule("min({3,5,7})",{res={3}})
--  rule("max({3,5,7})",{res={7}})
--  rule("min(3,5,7)",{res={3}})
--  rule("max(3,5,7)",{res={7}})
--  rule("sort({3,5,4})",{res={{3,4,5}}})
--  rule("sort(3,5,4)",{res={{3,4,5}}})
--  rule("average({3,5,4})",{res={4}})
--  rule("average(3,5,4)",{res={4}})
--  rule("size({3,2,1})",{res={3}})
--  rule("log('X')",{res={"X"}})
--  rule("match('abc','c')",{res={"c"}})
--  rule("match(123,2)",{res={"2"}})
--  rule("osdate('%c')",{res={os.date()}})
--  rule("ostime()",{res={os.time()}})
--  rule("fmt('%.2f',math.pi)",{res={"3.14"}})
--  rule("eval('3+8')",{res={11}})
--  rule("sunset",{res={fibaro.utils.toTime(fibaro.getValue(1,"sunsetHour"))}})
--  rule("sunrise",{res={fibaro.utils.toTime(fibaro.getValue(1,"sunriseHour"))}})
----  rule("dawn",{res={fibaro.utils.toTime(fibaro.getValue(1,"dawnHour"))}})
----  rule("dusk",{res={fibaro.utils.toTime(fibaro.getValue(1,"duskHour"))}})
--  rule("now",{res={fibaro.now()}})
--  rule("wnum",{res={fibaro.getWeekNumber()}})
--  rule("now..now+1",{res={true}})
--  rule("now-2..now-1",{res={false}})
--  rule("t/07:00",{res={fibaro.midnight()+7*3600}})
--  rule("n/(now-1)",{res={os.time()+24*3600-1}})
--  rule("+/01:00",{res={os.time()+3600}})
--  rule("HM(now)",{res={os.date("%H:%M")}})
--  rule("HMS(now)",{res={os.date("%H:%M:%S")}})
--  rule("{sign(0),sign(-3),sign(4)}",{res={{1,-1,1}}})
--  rule("rnd(99,99)",{res={99}})

----  rule("global",{res={16}})
----  rule("listglobals",{res={16}})
----  rule("deleteglobal",{res={16}})
----  rule("once")
--  rule("t0 = now+3",{res={fibaro.now()+3}})
--  rule("@t0 => 88; disable(); 42",{res={42}})
--  rule("#foo => 42",{res={42}})
--  rule("post(#foo); 17",{res={17}})

--  rule("local s = 0; for i=1,10 do s =s+1 end; s",{res={10}})
--  rule("local s,i = 0,0; while i < 10 do i=i+1; s =s+1 end; s",{res={10}})
--  rule("local s,i = 0,0; repeat i=i+1; s=s+1 until i>=10; s",{res={10}})
--  rule("if 5>4 then 55 else 77 end",{res={55}})
--  rule("if 5>6 then 55 else 77 end",{res={77}})
--  rule("if 5>6 then 55 elseif 5>4 then 66 else 77 end",{res={66}})
--  rule("if 5>6 then 55 elseif 5>6 then 66 else 88 end",{res={88}})
--  rule("local a=now; wait(4); now-a",{res={4}})
--  rule("trueFor(00:00:03,T0) => 65",{res={65}})
--  rule("T0=true; 64",{res={64}})
--  rule("wait(1);D0:value=77; D0:value",{res={77}})
--  rule("D0:value==true => log('Y')",{trace=true,res={'Y'}})
--  rule("D0:value=true; 88",{res={88}})
  D1 = 100--DT('com.fibaro.multilevelSwitch')
--  rule("D1:value=88",{res2=checkFib,res={[[fibaro.call(100,"setValue",88)]]}})
--  rule("D1:on",{res2=checkFib,res={[[fibaro.call(100,"turnOn")]]}})
--  rule("D1:off",{res2=checkFib,res={[[fibaro.call(100,"turnOff")]]}})
  rule("BSW:isOn",{res2=checkFib,res={[[fibaro.get(1100,"value")]]}})
--  rule("D1:state=true",{res2=checkFib,res={[[fibaro.call(100,"updateProperty","state",true)]]}})
end

function QuickApp:onInit()
  EVENTSCRIPT.setupES()
  setTimeout(function() self:main() end,1000)
end