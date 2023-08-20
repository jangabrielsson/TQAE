-- luacheck: globals ignore _debugFlags hc3_emulator QuickApp Util

_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { 
    onAction=true, http=false, UIEevent=true, trigger=true, post=true, dailys=true, pubsub=true, qa=true-- timersSched=true
  },
  --startTime="18:10:00",
  offline=true
}

--%%name="EventRunner4"
--%%type="com.fibaro.genericDevice"
--%%u1={label='ERname',text="..."}
--%%u2={button='debugTrigger', text='Triggers:ON', onReleased='FEventRunner4'}
--%%u3={button='debugPost', text='Post:ON', onReleased='FEventRunner4'}
--%%u4={button='debugRule', text='Rules:ON', onReleased='FEventRunner4'}
--%%u5={button='Test', text='Test', onReleased='FEventRunner4'}
--%%proxy=true

--%%fileoffset="dev/"
--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:jgabs_QAs/EventRunner/EventRunner4Engine.lua,EventRunner;
--FILE:jgabs_QAs/EventRunner/EventRunnerDoc.lua,Doc;

----------- Code -----------------------------------------------------------
_debugFlags.sourceTrigger = true  -- log incoming triggers
_debugFlags._allRefreshStates = false -- log all incoming refrshState events
_debugFlags.fcall=true     -- log fibaro.call
_debugFlags.post = true    -- log internal posts
_debugFlags.rule=true      -- log rules being invoked (true or false)
_debugFlags.ruleTrue=true  -- log only rules that are true
_debugFlags.pubsub=true    -- log pub/sub actions
_debugFlags.extendedErrors=true -- Add extra error info for events/timers
_debugFlags.trueFor=false   -- Log trueFor actions
_debugFlags.onaction=true   -- Log onActions
_debugFlags.uievent=true    -- Log uiEvents
_debugFlags.json=true       -- Convert tables to json in log calls
_debugFlags.html=true       -- Convert spaces to &nbsp in log output
_debugFlags.logTrigger=false -- Enable log source triggers (when log text for UI changes)
------------- Put your rules inside QuickApp:main() -------------------

function QuickApp:main()    -- EventScript version
  local rule = function(...) return self:evalScript(...) end          -- old rule function
  self:enableTriggerType({"device","global-variable","custom-event","profile","alarm","weather","location","quickvar","user"}) -- types of events we want
  local HT = { 
    keyfob = 26, 
    motion= 21,
    temp = 22,
    lux = 23,
  }

  self.color.banner='black'
  self.color.rule='green'
  self.color.info='purple'

  if hc3_emulator then
--    s0 = hc3_emulator.create.binarySwitch(65)
--    s1 = hc3_emulator.create.binarySwitch(66)
--    s2 = hc3_emulator.create.binarySwitch(67)
--    s3 = hc3_emulator.create.binarySwitch(68)
--    s4 = hc3_emulator.create.binarySwitch(69)
--    s5 = hc3_emulator.create.binarySwitch(70)
--    s6 = hc3_emulator.create.binarySwitch(71)
--    s7 = hc3_emulator.create.binarySwitch(72)
--    s8 = hc3_emulator.create.binarySwitch(73)
--    s1 = hc3_emulator.create.binarySensor(77)
--    s2 = hc3_emulator.create.binarySensor(88)
    s2 = hc3_emulator.create.multilevelSwitch(88)
    s3 = hc3_emulator.create.multilevelSwitch(89)
--    s2 = hc3_emulator.create.globalVariables{name="Test",value="10:00"}
    hc3_emulator.create.globalVariables{name='A',value="41"}
    hc3_emulator.create.globalVariables{name='B',value=nil}
  end

  Util.defvars(HT)
  Util.reverseMapDef(HT)
    --rule("#f4_office_remote{value='Pressed2'} =>  HT['办公室']['筒灯']:toggle")
    ---rule("@@00:00:05 => log('Hupp')")
    
    NOW = os.time() - fibaro.midnight() + 2
    rule("@NOW+3 & 11:00..21:01 => log('Upp')")
      
--  rule("#profile{property='activeProfile', value=AwayProfile} => enable('Away',true)") 
--  rule("#profile{property='activeProfile', value=HomeProfile} => enable('Home',true); r2.start()") 
--  rule("post(#profile{property='activeProfile', value=HomeProfile})") 
--  rule("wait(20); post(#profile{property='activeProfile', value=AwayProfile})")
--  alarms = 1
--  rule("alarms:armed => log('Some alarm armed')")
--  rule("alarms:allArmed => log('All alarm armed')")
--  rule("alarms:disarmed => log('All disarmed')")
--  rule("alarms:anyDisarmed => log('Any disarmed')")
--  rule("alarms:willArm => log('Any will arm')")
--  rule("{1,2}:allArmed => log('1,2 armed')")
--  rule("{1,2}:disarmed => log('1,2 disarmed')")
--  rule("wait(2); 0:alarm=true")
--  rule("0:armed => log('all armed')").print()
--  rule("0:armed==false => log('all disarmed')").print()
--  rule("2:armed => log('2 armed')")
--  rule("2:disarmed => log('2 disarmed')")
--  rule("2:willArm => log('2 will arm')")

--  rule("#foo=>kill(); log('A');wait(2);log('B')")
--  rule("post(#foo); wait(1); post(#foo)")

--  rule("#se-start => log('HC3 restarted')")
--  rule("#DST_changed => plugin.restart()") -- Restart ER when DST change

--  Phone = {2,107}
--  lights={267,252,65,67,78,111,129,158,292,127,216,210,205,286,297,302,305,410,384,389,392,272,329,276} -- eller hämta värden från HomeTable
--  rule("earthDates={2021/3/27/20:30,2022/3/26/20:30,2023/3/25/20:30}")
--  rule("for _,v in ipairs(earthDates) do log(osdate('Earth hour %c',v)); post(#earthHour,v) end")
--  rule("#earthHour => wait(00:00:10); Phone:msg=log('Earth Hour har inletts, belysningen tänds igen om 1 timme')")
--  rule("#earthHour => states = lights:value; lights:off; wait(01:00); lights:value = states")
--  -- Slut ---
---- Testar Earth hour --------
--  rule("#earthHour2 => states = lights:value; lights:off; wait(00:00:06); lights:value = states")
--  rule("@now+00:00:05 => post(#earthHour2)")
-- rule("@@00:01 & date('0/5 12-15 *') => log('ping')")
-- rule("@@00:00:05 => log(now % 2 == 1 & 'Tick' | 'Tock')")
-- rule("remote(1356,#foo)")
-- rule("wait(5); publish(#foo)")
-- rule("motion:value => log('Motion:%s',motion:last)")

--     rule("@{catch,05:00} => Util.checkForUpdates()")
--     rule("#File_update{} => log('New file version:%s - %s',env.event.file,env.event.version)")
--     rule("#File_update{} => Util.updateFile(env.event.file)")

--  rule("keyfob:central => log('Key:%s',env.event.value.keyId)")
--  rule("motion:value => log('Motion:%s',motion:value)")
--  rule("temp:temp => log('Temp:%s',temp:temp)")
--  rule("lux:lux => log('Lux:%s',lux:lux)")

--  rule("wait(3); log('Res:%s',http.get('https://jsonplaceholder.typicode.com/todos/1').data)")

--   Nodered.connect("http://192.168.1.50:1880/ER_HC3")
--  Nodered.connect("http://192.168.1.88:30011/ER_HC3")
--  rule("Nodered.post({type='echo1',value='Hello'},true).value")
--  rule("Nodered.post({type='echo1',value=42})")
--  rule("#echo1 => log('ECHO:%s',env.event.value)")

--    rule("log('Synchronous call:%s',Nodered.post({type='echo1',value=42},true).value)")

--  rule("#alarm{property='armed', value=true, id='$id'} => log('Zone %d armed',id)")
--  rule("#alarm{property='armed', value=false, id='$id'} => log('Zone %d disarmed',id)")
--  rule("#alarm{property='homeArmed', value=true} => log('Home armed')")
--  rule("#alarm{property='homeArmed', value=false} => log('Home disarmed')")
--  rule("#alarm{property='homeBreached', value=true} => log('Home breached')")
--  rule("#alarm{property='homeBreached', value=false} => log('Home safe')")

--  rule("#weather{property='$prop', value='$val'} => log('%s = %s',prop,val)")

--  rule("#profile{property='activeProfile', value='$val'} => log('New profile:%s',profile.name(val))")
--  rule("log('Current profile:%s',QA:profileName(QA:activeProfile()))")

--  rule("#customevent{name='$name'} => log('Custom event:%s',name)")
--  rule("#myBroadcast{value='$value'} => log('My broadcast:%s',value)")
--  rule("wait(5); QA:postCustomEvent('myEvent','this is a test')")
--  rule("wait(7); broadcast({type='myBroadcast',value=42})")
--  rule("#deviceEvent{id='$id',value='$value'} => log('Device %s %s',id,value)")
--  rule("#sceneEvent{id='$id',value='$value'} => log('Scene %s %s',id,value)")

    local errf = fibaro.errorf
    function fibaro.errorf(tag,fmt,...) self:post({type='er_error',msg=errf(tag,fmt,...)}) end
    
    rule("#er_error{msg=msg} => log('Error:%s',msg)")
    
  fibaro.event({type='_startup_'},function()
      Util.printBanner("Jang's HomeAutomation Engine (ER4v%s)",{self.E_VERSION},"green") -- Change to your own name...
      Util.printRules()
      Util.printInfo()
      self:addHourTask(Util.printInfo)
    end)

--  dofile("verifyHC3scripts.lua")
  return "silent"
end