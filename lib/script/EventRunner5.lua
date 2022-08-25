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

  local function rule(...) local args={...} setTimeout(function() EVENTSCRIPT.rule(unpack(args)) end,0) end

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

  local interceptValue = nil
  local function intercept(id)
    _debugFlags.fcall=true
    _debugFlags.fget=true
    _debugFlags.fscene=true
    EVENTSCRIPT.inhibitTrace=true    
    EVENTSCRIPT.interceptCalls(id,
      function(ctx,id,prop) interceptValue=fmt("get(%s,%s)",id,prop) return ctx.get(id,prop) end,      
      function(ctx,id,m,...) interceptValue=fibaro.fformat("call(%s)",fibaro.arr2str(",",id,m,...)) return ctx.call(id,m,...) end
    )
    return id 
  end

  BSW = intercept(hc3_emulator.create.binarySwitch(1100,"BSW"))
  MSW = intercept(hc3_emulator.create.multilevelSwitch(1101,"MSW"))
  BSE = intercept(hc3_emulator.create.binarySensor(1102,"BSE"))
  MSE = intercept(hc3_emulator.create.multilevelSensor(1103,"MSE"))  
  PLAYER = intercept(hc3_emulator.create.player(1104,"PLAYER"))
  ROLLER = intercept(hc3_emulator.create.rollerShutter(1105,"ROLLER"))
  LOCK = intercept(hc3_emulator.create.doorLock(1106,"LOCK"))
  THERMO = intercept(hc3_emulator.create.thermostat(1107,"THERMO"))
--  reverseMapDef({BSW=BSW,MSW=MSW,BSE=BSE})

  local TIMEOUT = 10000
  local tests={}
  local function check(env,...)
    local opts = env.opts
    if tests[opts.nr] then tests[opts.nr]=clearTimeout(tests[opts.nr]) end
    local res2 = {...}
    if type(opts.res)=='function' then opts.res={opts.res()} end
    if opts.res2 then res2 = type(opts.res2)=='function' and opts.res2(res2) or opts.res2 end
    local r1,r2=encode(opts.res),encode(res2)
    if fibaro.utils.equal(opts.res,res2) then 
      if opts.logOK then quickApp:debugf(fmtStr,"OK'"..opts.doc:sub(1,35).."'",r1:sub(1,15),r2:sub(1,15)) end
    else quickApp:errorf(fmtStr,"'"..opts.doc:sub(1,35).."'",r1:sub(1,15),r2:sub(1,15)) end
    return ...
  end

  local function create(opts)
    interceptValue = nil
    tests[opts.nr]=setTimeout(function() tests[opts.nr]=nil; quickApp:errorf("rule %s timed out",tonumber(opts.nr) or opts.doc) end,TIMEOUT)
  end

  local function checkFib(...) return {interceptValue} end
  local function checkTrace(...) return {EVENTSCRIPT.lastTrace:match("fibaro.(.-) =>")} end

  EVENTSCRIPT.ruleOpts.bodyFun = check
  EVENTSCRIPT.ruleOpts.createFun = create
  EVENTSCRIPT.ruleOpts.logOK = true
  EVENTSCRIPT.ruleOpts.logRes = false

  defTriggerVar("T0")

  rule("a = true & false",{res={false}})
  rule("a = true or false",{res={true}})
  rule("a = !false",{res={true}})
  rule("a = 6 + 10",{res={16}})
  rule("b = a + 10",{res={26}})
  rule("-10",{res={-10}})
  rule("-b+a",{res={-10}})
  rule("round(10.2)",{res={10}})
  rule("round(10.6)",{res={11}})
  rule("sum(3,5,7)",{res={15}})
  rule("sum({3,5,7})",{res={15}})
  rule("min({3,5,7})",{res={3}})
  rule("max({3,5,7})",{res={7}})
  rule("min(3,5,7)",{res={3}})
  rule("max(3,5,7)",{res={7}})
  rule("sort({3,5,4})",{res={{3,4,5}}})
  rule("sort(3,5,4)",{res={{3,4,5}}})
  rule("average({3,5,4})",{res={4}})
  rule("average(3,5,4)",{res={4}})
  rule("size({3,2,1})",{res={3}})
  rule("log('X')",{res={"X"}})
  rule("match('abc','c')",{res={"c"}})
  rule("match(123,2)",{res={"2"}})
  rule("osdate('%c')",{res=os.date})
  rule("ostime()",{res=os.time})
  rule("fmt('%.2f',math.pi)",{res={"3.14"}})
  rule("eval('3+8')",{res={11}})
  rule("sunset",{res={fibaro.utils.toTime(fibaro.getValue(1,"sunsetHour"))}})
  rule("sunrise",{res={fibaro.utils.toTime(fibaro.getValue(1,"sunriseHour"))}})
--  rule("dawn",{res={fibaro.utils.toTime(fibaro.getValue(1,"dawnHour"))}})
--  rule("dusk",{res={fibaro.utils.toTime(fibaro.getValue(1,"duskHour"))}})
  rule("now",{res=fibaro.now})
  rule("wnum",{res={fibaro.getWeekNumber()}})
  rule("now..now+1",{res={true}})
  rule("now-2..now-1",{res={false}})
  rule("t/07:00",{res={fibaro.midnight()+7*3600}})
  rule("n/(now-1)",{res=function() return os.time()+24*3600-1 end})
  rule("+/01:00",{res=function() return os.time()+3600 end})
  rule("HM(now)",{res=function() return os.date("%H:%M") end})
  rule("HMS(now)",{res=function() return os.date("%H:%M:%S") end})
  rule("{sign(0),sign(-3),sign(4)}",{res={{1,-1,1}}})
  rule("rnd(99,99)",{res={99}})

----  rule("global",{res={16}})
----  rule("listglobals",{res={16}})
----  rule("deleteglobal",{res={16}})
----  rule("once")
  rule("t0 = now+3",{res=function() return fibaro.now()+3 end})
  rule("@t0 => 88; disable(); 42",{res={42}})
  rule("#foo => 42",{res={42}})
  rule("post(#foo); 17",{res={17}})

  rule("local s = 0; for i=1,10 do s =s+1 end; s",{res={10}})
  rule("local s,i = 0,0; while i < 10 do i=i+1; s =s+1 end; s",{res={10}})
  rule("local s,i = 0,0; repeat i=i+1; s=s+1 until i>=10; s",{res={10}})
  rule("if 5>4 then 55 else 77 end",{res={55}})
  rule("if 5>6 then 55 else 77 end",{res={77}})
  rule("if 5>6 then 55 elseif 5>4 then 66 else 77 end",{res={66}})
  rule("if 5>6 then 55 elseif 5>6 then 66 else 88 end",{res={88}})
  rule("local a=now; wait(4); now-a",{res={4}})
  rule("trueFor(00:00:03,T0) => 65",{res={65}})
  rule("T0=true; 64",{res={64}})
  rule("wait(1);MSW:value=77;MSW:value",{res={99}}) -- ToDo! How to handle this?
  rule("BSW:value==true => log('Y')",{trace=true,res={'Y'}})
  rule("MSW:value=88",{res2=checkFib,res={[[call(1101,setValue,88)]]}})

  rule("BSW:isOn",{res2=checkFib,res={[[get(1100,value)]]}})
  rule("BSW:isOff",{res2=checkFib,res={[[get(1100,value)]]}})
  rule("BSW:on",{res2=checkFib,res={[[call(1100,turnOn)]]}})
  rule("BSW:off",{res2=checkFib,res={[[call(1100,turnOff)]]}})
  rule("BSW:state=true",{res2=checkFib,res={[[call(1100,updateProperty,state,true)]]}})
  rule("BSW:value",{res2=checkFib,res={[[get(1100,value)]]}})
  rule("MSW:value=99",{res2=checkFib,res={[[call(1101,setValue,99)]]}})
  rule("MSW:bat",{res2=checkFib,res={[[get(1101,batteryLevel)]]}})
  rule("MSW:power",{res2=checkFib,res={[[get(1101,power)]]}})
  rule("MSW:safe",{res2=checkFib,res={[[get(1101,value)]]}})
  rule("MSW:breached",{res2=checkFib,res={[[get(1101,value)]]}})
  rule("MSW:last",{res2=checkFib,res={[[get(1101,value)]]}})
  rule("MSW:isOpen",{res2=checkFib,res={[[get(1101,value)]]}})
  rule("MSW:isClosed",{res2=checkFib,res={[[get(1101,value)]]}})
  rule("MSW:lux",{res2=checkFib,res={[[get(1101,value)]]}})
  rule("MSW:volume",{res2=checkFib,res={[[get(1101,volume)]]}})
  rule("MSW:position",{res2=checkFib,res={[[get(1101,position)]]}})
  rule("MSW:temp",{res2=checkFib,res={[[get(1101,value)]]}})


  rule("MSW:coolingThermostatSetpoint",{res2=checkFib,res={[[get(1101,coolingThermostatSetpoint)]]}})
  rule("MSW:coolingThermostatSetpointCapabilitiesMin",{res2=checkFib,res={[[get(1101,coolingThermostatSetpointCapabilitiesMin)]]}})
  rule("MSW:coolingThermostatSetpointCapabilitiesMax",{res2=checkFib,res={[[get(1101,coolingThermostatSetpointCapabilitiesMax)]]}})
  rule("MSW:coolingThermostatSetpointFuture",{res2=checkFib,res={[[get(1101,coolingThermostatSetpointFuture)]]}})
  rule("MSW:coolingThermostatSetpointStep",{res2=checkFib,res={[[get(1101,coolingThermostatSetpointStep)]]}})
  rule("MSW:heatingThermostatSetpoint",{res2=checkFib,res={[[get(1101,heatingThermostatSetpoint)]]}})
  rule("MSW:heatingThermostatSetpointCapabilitiesMax",{res2=checkFib,res={[[get(1101,heatingThermostatSetpointCapabilitiesMax)]]}})
  rule("MSW:heatingThermostatSetpointCapabilitiesMin",{res2=checkFib,res={[[get(1101,heatingThermostatSetpointCapabilitiesMin)]]}})
  rule("MSW:heatingThermostatSetpointFuture",{res2=checkFib,res={[[get(1101,heatingThermostatSetpointFuture)]]}})
  rule("MSW:heatingThermostatSetpointStep",{res2=checkFib,res={[[get(1101,heatingThermostatSetpointStep)]]}})
  rule("MSW:thermostatFanMode",{res2=checkFib,res={[[get(1101,thermostatFanMode)]]}})
  rule("MSW:thermostatFanOff",{res2=checkFib,res={[[get(1101,thermostatFanOff)]]}})
  rule("MSW:thermostatMode",{res2=checkFib,res={[[get(1101,thermostatMode)]]}})
  rule("MSW:thermostatModeFuture",{res2=checkFib,res={[[get(1101,thermostatModeFuture)]]}})
  rule("PLAYER:play",{res2=checkFib,res={[[call(1104,play)]]}})
  rule("PLAYER:pause",{res2=checkFib,res={[[call(1104,pause)]]}})
  rule("PLAYER:volume=88",{res2=checkFib,res={[[call(1104,setVolume,88)]]}})
  rule("PLAYER:mute",{res2=checkFib,res={[[get(1104,mute)]]}})
  rule("PLAYER:mute=0",{res2=checkFib,res={[[call(1104,setMute,0)]]}})
  rule("ROLLER:open",{res2=checkFib,res={[[call(1105,open)]]}})
  rule("ROLLER:close",{res2=checkFib,res={[[call(1105,close)]]}})
  rule("ROLLER:stop",{res2=checkFib,res={[[call(1105,stop)]]}})
  rule("LOCK:secure",{res2=checkFib,res={[[call(1106,secure)]]}})
  rule("LOCK:unsecure",{res2=checkFib,res={[[call(1106,unsecure)]]}})
  rule("LOCK:isSecure",{res2=checkFib,res={[[get(1106,secured)]]}})
  rule("LOCK:isUnsecure",{res2=checkFib,res={[[get(1106,secured)]]}})
  rule("MSW:name",{res={"MSW"}})
  rule("MSW:HTname",{res={1101}})
  rule("MSW:roomName",{res={"Default Room"}})
  rule("MSW:trigger",{res2=checkFib,res={[[get(1101,value)]]}})
  rule("MSW:time",{res2=checkFib,res={[[get(1101,time)]]}})
  rule("MSW:manual",{res={-1}})
  rule("MSW:start",{res2=checkTrace,res={'scene("execute",[1101])'}})
  rule("MSW:kill",{res2=checkTrace,res={'scene("kill",[1101])'}})
  rule("BSW:toggle",{res2=checkFib,res={[[call(1100,toggle)]]}})
  rule("MSW:wake",{res2=checkTrace,res={[[call(1,"wakeUpDeadDevice",1101)]]}})
  rule("MSW:removeSchedule",{res2=checkFib,res={[[call(1101,removeSchedule)]]}})
  rule("MSW:retryScheduleSynchronization",{res2=checkFib,res={[[call(1101,retryScheduleSynchronization)]]}})
  rule("MSW:setAllSchedules",{res2=checkFib,res={[[call(1101,setAllSchedules)]]}})
  rule("MSW:levelIncrease",{res2=checkFib,res={[[call(1101,startLevelIncrease)]]}})
  rule("MSW:levelDecrease",{res2=checkFib,res={[[call(1101,startLevelDecrease)]]}})
  rule("MSW:levelStop",{res2=checkFib,res={[[call(1101,stopLevelChange)]]}})

  rule("MSW:levelStop",{res2=checkFib,res={[[call(1101,stopLevelChange)]]}})
  rule("MSW:levelStop",{res2=checkFib,res={[[call(1101,stopLevelChange)]]}})
end

function QuickApp:onInit()
  EVENTSCRIPT.setupES()
  setTimeout(function() self:main() end,1000)
end