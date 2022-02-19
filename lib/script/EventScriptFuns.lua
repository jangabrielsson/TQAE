EVENTSCRIPT = EVENTSCRIPT or {}
EVENTSCRIPT.builtins = EVENTSCRIPT.builtins or {}

function EVENTSCRIPT.setupFuns()
  local compiler = EVENTSCRIPT.compiler
  local builtins = EVENTSCRIPT.builtins
  local fmt = string.format
  
  local util = fibaro.utils
  local mapOr,mapAnd,mapF=util.mapOr,util.mapAnd,function(f,l,s) util.mapF(f,l,s); return true end
  local midnight = fibaro.midnight
  
  local function _assert(t,f,...) if not t then error(fmt(f,...)) end end
  
  local alarmCache = {}
  for _,p in ipairs(api.get("/alarms/v1/partitions") or {}) do -- prime alarm cache
    alarmCache[p.id] = { 
      armed = p.armed, breached = p.breached, breachDelay = p.breachDelay, armDelay = p.armDelay, secondsToArm = p.secondsToArm
    }
  end
  quickApp:event({type='alarm'},function(env) -- update alarm cache
      local e = env.event
      if e.property=='homeArmed' then
        e.id=0
        e.property='armed' 
      end
      local c = alarmCache[e.id or 0] or {}
      c[e.property]=e.value
      alarmCache[e.id or 0]  = c
    end)
  local function alarm(id,_) 
    if id == 0 then -- Create combined "house partition"
      local ps = api.get("/alarms/v1/partitions") or {}
      if #ps == 0 then return {} end
      local p,c = {},alarmCache[ps[1].id]
      p.devices = ps[1].devices
      p.armed = c.armed
      p.breached = c.breached
      p.breachDelay = c.breachDelay
      p.armDelay = c.armDelay
      p.secondsToArm = c.secondsToArm
      p.id = c.id
      local devMap = {}
      for _,d in ipairs(p.devices) do devMap[d]=true end
      for i=2,#ps do
        local d = alarmCache[ps[i].id] or {}
        p.breached = p.breached or d.breached
        p.armed = p.armed and d.armed
        p.breachDelay = math.min(p.breachDelay,d.breachDelay or 0)
        p.armDelay = math.min(p.armDelay,d.armDelay or 0)
        for _,d0 in ipairs(d.devices or {}) do devMap[d0]=true end
      end
      p.name="House"
      p.id = 0
      local devices = {}
      for d,_ in pairs(devMap) do devices[#devices+1]=d end
      p.devices = devices
      return p
    else return api.get("/alarms/v1/partitions/"..id) end
  end

  local alarmsToWatch = {}
  local alarmRef = nil
  local alarmWatchInterval = 2000
  local armedPs={}

  local function watchAlarms()
    for pid,_ in pairs(alarmsToWatch) do
      local p = api.get("/alarms/v1/partitions/"..pid) or {}
      if p.secondsToArm and not armedPs[p.id] then
        quickApp:post({type='alarm',property='willArm',id=p.id,value=p.secondsToArm})
      end
      armedPs[p.id] = p.secondsToArm
    end
  end

  local alarmFuns = {
    ['true']=function(id) fibaro.alarm(id,"arm") return true end,
    ['false']=function(id) fibaro.alarm(id,"disarm") return true end,
    ['watch']=function(id) 
      if id==0 then
        for id0,_ in ipairs(alarmCache) do alarmsToWatch[id0]=true end
      else alarmsToWatch[id]=true end
      if alarmRef==nil then alarmRef = setInterval(watchAlarms,alarmWatchInterval) end
      return true 
    end, 
    ['unwatch']=function(id) 
      if id == 0 then 
        alarmsToWatch = {}
      else alarmsToWatch[id]=nil end
      if  next(alarmsToWatch)==nil and alarmRef then clearInterval(alarmRef); alarmRef=nil end
      return true 
    end, 
  }
  local function gp(pid) return alarmCache[pid] or {} end
  local function setAlarm(id,_,val)
    local action = tostring(val)
    if not alarmFuns[action] then error("Bad argument to :alarm") end
    if id ~= 0 then return alarmFuns[action](id)
    else
      if action=='true' then fibaro.alarm("arm") return true
      elseif action == 'false' then fibaro.alarm("disarm") return true
      else
        alarmFuns[action](id)
        return true
      end
    end
  end

  local _getFun = function(id,prop) return fibaro.get(id,prop) end
  local function BN(x) if type(x)=='boolean' then return x and 1 or 0 else return x end end
  local get = _getFun
  local function on(id,prop) return BN(fibaro.get(id,prop)) > 0 end
  local function off(id,prop) return BN(fibaro.get(id,prop)) == 0 end
  local function last(id,prop) local _,t=fibaro.get(id,prop); return t and os.time()-t or 0 end
  local function cce(id,_,e) e=e.event; return e.type=='device' and e.property=='centralSceneEvent'and e.id==id and e.value or {} end
  local function ace(id,_,e) e=e.event; return e.type=='device' and e.property=='accessControlEvent' and e.id==id and e.value or {} end
  local function sae(id,_,e) e=e.event; return e.type=='device' and e.property=='sceneActivationEvent' and e.id==id and e.value.sceneId end
  local function setProfile(id,_,val) if val then fibaro.profile("activateProfile",id) end return val end
  local function setState(id,cmd,val) fibaro.call(id,"updateProperty","state",val); return val end
  local function setProps(id,cmd,val) fibaro.call(id,"updateProperty",cmd,val); return val end
  local function profile(id,_) return api.get("/profiles/"..id.."?showHidden=true") end
  local function call(id,cmd) fibaro.call(id,cmd); return true end
  local function set(id,cmd,val) fibaro.call(id,cmd,val); return val end
  local function pushMsg(id,cmd,val) fibaro.alert(cmd,{id},val,false); return val end
  local function set2(id,cmd,val) fibaro.call(id,cmd,table.unpack(val)); return val end
  local function dim2(id,_,val) Util.dimLight(id,table.unpack(val)) end --sec,dir,step,curve,start,stop)
  local function child(id,_) for _,c in pairs(quickApp.childDevices) do if c.eid==id then return c end end return nil end

  local getFuns={}
  getFuns.value={method=get,prop='value',table=false,trigger=true}
  getFuns.state={method=get,prop='state',table=false,trigger=true}
  getFuns.bat={method=get,prop='batteryLevel',table=false,trigger=true}
  getFuns.power={method=get,prop='power',table=false,trigger=true}
  getFuns.isOn={method=on,prop='value',table=mapOr,trigger=true}
  getFuns.isOff={method=off,prop='value',table=mapAnd,trigger=true}
  getFuns.isAllOn={method=on,prop='value',table=mapAnd,trigger=true}
  getFuns.isAnyOff={method=off,prop='value',table=mapOr,trigger=true}
  getFuns.last={method=last,prop='value',table=false,trigger=true}
  getFuns.alarm={method=alarm,prop='alarm',table=false,trigger=true}
  getFuns.armed={method=function(id) return gp(id).armed end,prop='armed',table=mapOr,trigger=true}
  getFuns.allArmed={method=function(id) return gp(id).armed end,prop='armed',table=mapAnd,trigger=true}
  getFuns.disarmed={method=function(id,_,_) return not gp(id).armed end,prop='armed',table=mapAnd,trigger=true}
  getFuns.anyDisarmed={method=function(id,_,_) return not gp(id).armed end,prop='armed',table=mapOr,trigger=true}
  getFuns.alarmBreached={method=function(id) return gp(id).breached end,prop='breached',table=mapOr,trigger=true}
  getFuns.alarmSafe={method=function(id) return not gp(id).breached end,prop='breached',table=mapAnd,trigger=true}
  getFuns.allAlarmBreached={method=function(id) return gp(id).breached end,prop='breached',table=mapAnd,trigger=true}
  getFuns.anyAlarmSafe={method=function(id) return not gp(id).breached end,prop='breached',table=mapOr,trigger=true}
  getFuns.willArm={method=function(id) return armedPs[id] end,prop='willArm',table=mapOr,trigger=true}
  getFuns.allWillArm={method=function(id) return armedPs[id] end,prop='willArm',table=mapAnd,trigger=true}
  getFuns.child={method=child,prop="",table=false,trigger=false}
  getFuns.profile={method=profile,prop='profile',table=false,trigger=false}
  getFuns.scene={method=sae,prop='sceneActivationEvent',table=false,trigger=true}
  getFuns.access={method=ace,prop='accessControlEvent',table=false,trigger=true}
  getFuns.central={method=cce,prop='centralSceneEvent',table=false,trigger=true}
  getFuns.safe={method=off,prop='value',table=mapAnd,trigger=true}
  getFuns.breached={method=on,prop='value',table=mapOr,trigger=true}
  getFuns.isOpen={method=on,prop='value',table=mapOr,trigger=true}
  getFuns.isClosed={method=off,prop='value',table=mapAnd,trigger=true}
  getFuns.lux={method=get,prop='value',table=false,trigger=true}
  getFuns.volume={method=get,prop='volume',table=false,trigger=true}
  getFuns.position={method=get,prop='position',table=false,trigger=true}
  getFuns.temp={method=get,prop='value',table=false,trigger=true}
  getFuns.coolingThermostatSetpoint={method=get,prop='coolingThermostatSetpoint',table=false,trigger=true}
  getFuns.coolingThermostatSetpointCapabilitiesMax={method=get,prop='coolingThermostatSetpointCapabilitiesMax',table=false,trigger=true}
  getFuns.coolingThermostatSetpointCapabilitiesMin={method=get,prop='coolingThermostatSetpointCapabilitiesMin',table=false,trigger=true}
  getFuns.coolingThermostatSetpointFuture={method=get,prop='coolingThermostatSetpointFuture',table=false,trigger=true}
  getFuns.coolingThermostatSetpointStep={method=get,prop='coolingThermostatSetpointStep',table=false,trigger=true}
  getFuns.heatingThermostatSetpoint={method=get,prop='heatingThermostatSetpoint',table=false,trigger=true}
  getFuns.heatingThermostatSetpointCapabilitiesMax={method=get,prop='heatingThermostatSetpointCapabilitiesMax',table=false,trigger=true}
  getFuns.heatingThermostatSetpointCapabilitiesMin={method=get,prop='heatingThermostatSetpointCapabilitiesMin',table=false,trigger=true}
  getFuns.heatingThermostatSetpointFuture={method=get,prop='heatingThermostatSetpointFuture',table=false,trigger=true}
  getFuns.heatingThermostatSetpointStep={method=get,prop='heatingThermostatSetpointStep',table=false,trigger=true}
  getFuns.thermostatFanMode={method=get,prop='thermostatFanMode',table=false,trigger=true}
  getFuns.thermostatFanOff={method=get,prop='thermostatFanOff',table=false,trigger=true}
  getFuns.thermostatMode={method=get,prop='thermostatMode',table=false,trigger=true}
  getFuns.thermostatModeFuture={method=get,prop='thermostatModeFuture',table=false,trigger=true}
  getFuns.on={method=call,prop='turnOn',table=mapF,trigger=true}
  getFuns.off={method=call,prop='turnOff',table=mapF,trigger=true}
  getFuns.play={method=call,prop='play',table=mapF,trigger=false}
  getFuns.pause={method=call,prop='pause',table=mapF,trigger=false}
  getFuns.open={method=call,prop='open',table=mapF,trigger=true}
  getFuns.close={method=call,prop='close',table=mapF,trigger=true}
  getFuns.stop={method=call,prop='stop',table=mapF,trigger=true}
  getFuns.secure={method=call,prop='secure',table=mapF,trigger=false}
  getFuns.unsecure={method=call,prop='unsecure',table=mapF,trigger=false}
  getFuns.isSecure={method=on,prop='secured',table=mapAnd,trigger=true}
  getFuns.isUnsecure={method=off,prop='secured',table=mapOr,trigger=true}
  getFuns.name={method=function(id) return fibaro.getName(id) end,prop=false,table=false,trigger=false}
  getFuns.HTname={method=function(id) return Util.reverseVar(id) end,prop=false,table=false,trigger=false}
  getFuns.roomName={method=function(id) return fibaro.getRoomNameByDeviceID(id) end,prop=false,table=false,trigger=false}
  getFuns.trigger={method=function() return true end,prop='value',table=false,trigger=true}
  getFuns.time={method=get,prop='time',table=false,trigger=true}
  getFuns.manual={method=function(id) return quickApp:lastManual(id) end,prop='value',table=false,trigger=true}
  getFuns.start={method=function(id) return fibaro.scene("execute",{id}) end,prop="",table=mapF,trigger=false}
  getFuns.kill={method=function(id) return fibaro.scene("kill",{id}) end,prop="",table=mapF,trigger=false}
  getFuns.toggle={method=call,prop='toggle',table=mapF,trigger=true}
  getFuns.wake={method=call,prop='wakeUpDeadDevice',table=mapF,trigger=true}
  getFuns.removeSchedule={method=call,prop='removeSchedule',table=mapF,trigger=true}
  getFuns.retryScheduleSynchronization={method=call,prop='retryScheduleSynchronization',table=mapF,trigger=true}
  getFuns.setAllSchedules={method=call,prop='setAllSchedules',table=mapF,trigger=true}
  getFuns.levelIncrease={method=call,prop='startLevelIncrease',table=mapF,trigger=false}
  getFuns.levelDecrease={method=call,prop='startLevelDecrease',table=mapF,trigger=false}
  getFuns.levelStop={method=call,prop='stopLevelChange',table=mapF,trigger=false}

  local setFuns={}
  setFuns.R={method=set,p='setR'}
  setFuns.G={method=set,p='setG'}
  setFuns.B={method=set,p='setB'}
  setFuns.W={method=set,p='setW'}
  setFuns.value={method=set,p='setValue'}
  setFuns.state={method=setState,p='setState'}
  setFuns.alarm={method=setAlarm,p='setAlarm'}
  setFuns.armed={method=setAlarm,p='setAlarm'}
  setFuns.profile={method=setProfile,p='setProfile'}
  setFuns.time={method=set,p='setTime'}
  setFuns.power={method=set,p='setPower'}
  setFuns.targetLevel={method=set,p='setTargetLevel'}
  setFuns.interval={method=set,p='setInterval'}
  setFuns.mode={method=set,p='setMode'}
  setFuns.setpointMode={method=set,p='setSetpointMode'}
  setFuns.defaultPartyTime={method=set,p='setDefaultPartyTime'}
  setFuns.scheduleState={method=set,p='setScheduleState'}
  setFuns.color={method=set2,p='setColor'}
  setFuns.volume={method=set,p='setVolume'}
  setFuns.position={method=set,p='setPosition'}
  setFuns.positions={method=setProps,p='availablePositions'}
  setFuns.mute={method=set,p='setMute'}
  setFuns.thermostatSetpoint={method=set2,p='setThermostatSetpoint'}
  setFuns.thermostatMode={method=set,p='setThermostatMode'}
  setFuns.heatingThermostatSetpoint={method=set,p='setHeatingThermostatSetpoint'}
  setFuns.coolingThermostatSetpoint={method=set,p='setCoolingThermostatSetpoint'}
  setFuns.thermostatFanMode={method=set,p='setThermostatFanMode'}
  setFuns.schedule={method=set2,p='setSchedule'}
  setFuns.dim={method=dim2,p='dim'}
  setFuns.msg={method=pushMsg,p='push'}
  setFuns.defemail={method=set,p='sendDefinedEmailNotification'}
  setFuns.btn={method=set,p='pressButton'} -- ToDo: click button on QA?
  setFuns.email={method=function(id,_,val) local h,m = val:match("(.-):(.*)"); fibaro.alert('email',{id},val) return val end,p=""}
  setFuns.start={method=function(id,_,val) 
      if isEvent(val) then quickApp:postRemote(id,val) else fibaro.scene("execute",{id},val) return true end 
    end,p=""}

  for p,v in pairs(getFuns) do
    assert(v.method~=nil and v.prop~=nil and v.table~=nil and v.trigger~=nil,"Bad "..p)
  end
  for p,v in pairs(setFuns) do
    assert(v.method~=nil and v.p~=nil,"Bad "..p)
  end

  EVENTSCRIPT.getFuns=getFuns
  EVENTSCRIPT.setFuns=setFuns


  local getArg,peekArg = compiler.hooks.getArg,compiler.hooks.peekArg
  local instr,instrc={},{}
--[[
<number>:<prop>
{<table>}:<prop>
<custom>:<prop>
--]]

  local function resolveID(id)
    local typ=type(id)
    if typ=='number' then
      local cd = customDeviceId[id]
      return cd or defaultDeviceHandler
    elseif typ=='table' then
      return customTableDeviceHandler[prop] or defaultTableDeviceHandler
    elseif typ=='userdata' then return id
    else error("Bad device") end
  end

  local function getProp(ids,prop)
    local propM = getFuns[prop]
    if type(ids)=='table' then
      local r = {}
      for _,id in ipairs(ids) do
        r[#r+1]=getProp(id,prop)
      end
      if propM and propM.table then return propM.table(r) else return r end
    else
      if propM then return propM.method(ids,prop)
      else return fibaro.getValue(ids,prop) end
    end
  end

  local function setProp(ids,prop,value)
    local propM = setFuns[prop]
    if type(ids)=='table' then
      local r = {}
      for _,id in ipairs(ids) do
        r[#r+1]=setProp(id,prop,value)
      end
      if propM and propM.table then return propM.table(r) else return r end
    else
      if propM then propM.method(ids,prop,value)
      else fibaro.call(ids,'setValue',prop,value) end
      return value
    end
  end

  function EVENTSCRIPT.addPropHandler(prop,get,set)
    getFuns[prop]=get
    setFuns[prop]=set
  end

  ------------- EventScript instructions

  instr['getprop']= function(i,st,env)
    local prop,id = i[2],getArg(i[3],st)
    st.push(getProp(id,prop))
  end

  instr['setprop']= function(i,st,env) 
    local prop,id,value = i[2],getArg(i[3],st),getArg(i[4],st)
    st.push(setProp(id,prop,value))
  end

  instr['##'] = function(i,st,env) st.push(#st.pop()) end
  instr['@'] = function(i,st,env) st.push(st.pop()) end
  instr['@@'] = function(i,st,env) st.push(st.pop()) end

--  local simpleFuns={num=tonumber,str=tostring,idname=Util.reverseVar,time=toTime,['type']=type,
--    tjson=safeEncode,fjson=json.decode}
--  for n,f in pairs(simpleFuns) do instr[n]=function(s,_,_,_) return s.push(f(s.pop())) end end

  local reservedVars = {
    "sunset","sunrise","midnight","dawn","dusk","now","wnum"
  }
  for _,n in ipairs(reservedVars) do compiler.hooks.reservedVars[n]=true end
  
  instr['sunset']=function(i,s) s.push(toTime(fibaro.getValue(1,'sunsetHour'))) end
  instr['sunrise']=function(i,s) s.push(toTime(fibaro.getValue(1,'sunriseHour'))) end
  instr['midnight']=function(i,s) s.push(midnight()) end
  instr['dawn']=function(i,s) s.push(toTime(fibaro.getValue(1,'dawnHour'))) end
  instr['dusk']=function(i,s) s.push(toTime(fibaro.getValue(1,'duskHour'))) end
  instr['now']=function(i,s) s.push(os.time()-midnight()) end
  instr['wnum']=function(i,s) s.push(Util.getWeekNumber(os.time())) end
  instr['%today']=function(i,s) s.push(midnight()+s.pop()) end
  instr['%nexttime']=function(i,s) local t=s.pop()+midnight(); s.push(t >= os.time() and t or t+24*3600) end
  instr['%plustime']=function(i,s) s.push(os.time()+s.pop()) end
  instr['%daily'] = function(i,s) s.pop() s.push(true) end
  instr['%interv'] = function(i,s) local _ = s.pop(); s.push(true) end
  instr['redaily'] = function(i,s) s.push(Rule.restartDaily(s.pop())) end
  instr['%always'] = function(i,s) local v = s.pop(n) s.push(v or true) end
  instr['betw'] = function(i,s) local t2,t1,time=s.pop(),s.pop(),os.time()
    _assert(tonumber(t1) and tonumber(t2),"Bad arguments to between '...', '%s' '%s'",t1 or "nil", t2 or "nil")
    if t1  > 24*60*60 then
      s.push(t1 <= time and t2 >= time)
    else
      local now = time-midnight()
      if t1<=t2 then s.push(t1 <= now and now <= t2) else s.push(now >= t1 or now <= t2) end 
    end
  end
  instr['%eventmatch'] = function(s,_,e,i) 
    local ev,evp=i[4],i[3]; 
    local vs = fibaro.EM.match(evp,e.event)
    if vs then for k,v in pairs(vs) do e.locals[k]={v} end end -- Uneccesary? Alread done in head matching.
    s.push(e.event and vs and ev or false) 
  end


  instrc['HM'] = function(i,s) local t = getArg(i[3],s); s.push(os.date("%H:%M",t < os.time() and t+midnight() or t)) end
  instrc['HMS'] = function(i,s) local t = getArg(i[3],s); s.push(os.date("%H:%M:%S",t < os.time() and t+midnight() or t)) end
  instrc['sign'] = function(i,s) s.push(tonumber(getArg(i[3],s)) < 0 and -1 or 1) end
  instrc['rnd'] = function(i,s) 
    local n,mi,ma=i[2] 
    if n>1 then ma,mi=getArg(i[4],s),getArg(i[3],s) else mi,ma=1,getArg(i[3],s) end
    s.push(math.random(mi,ma)) 
  end
  instrc['round'] = function(i,s) local v=getArg(i[3],s); s.push(math.floor(v+0.5)) end
  instrc['sum'] = function(i,s) local m,res=getArg(i[3],s),0 for _,x in ipairs(m) do res=res+x end s.push(res) end
  instrc['average'] = function(i,s) local m,res=getArg(i[3],s),0 for _,x in ipairs(m) do res=res+x end s.push(res/#m) end
  instrc['size'] = function(i,s) s.push(#(getArg(i[3],s))) end
  local function getNargs(i,s)
    if type(peekArg(i[3],s)) == 'table' then return getArg(i[3],s) end
    local args = {}
    for j=i[2]+2,3,-1 do args[j-2]=getArg(i[j],s) end
    return args
  end
  instrc['min'] = function(i,s) s.push(math.min(table.unpack(getNargs(i,s)))) end
  instrc['max'] = function(i,s) s.push(math.min(table.unpack(getNargs(i,s)))) end
  instrc['sort'] = function(i,s) local a = getNargs(i,s); table.sort(a) s.push(a) end
  instrc['match'] = function(i,s) local a,b=getArg(i[4],s),getArg(i[3],s); s.push(string.match(b,a)) end
  instrc['osdate'] = function(i,s) local n=i[2] local t,str = n>1 and getArg(i[4],s) or nil,getArg(i[3],s) s.push(os.date(str,t)) end
  instrc['ostime'] = function(i,s) s.push(os.time()) end
  instrc['fmt'] = function(i,s) s.push(string.format(table.unpack(getNargs(i,s)))) end
  instrc['eval'] = function(i,s) s.push(Rule.eval(getArg(i[3],s),{print=false})) end
  instrc['global'] = function(i,s)  s.push(api.post("/globalVariables/",{name=getArg(i[3],s)})) end
  instrc['listglobals'] = function(i,s) s.push(api.get("/globalVariables/")) end
  instrc['deleteglobal'] = function(i,s) s.push(api.delete("/globalVariables/"..getArg(i[3],s))) end
  instrc['once'] = function(i,s) 
    if n==1 then local f; i[4],f = s.pop(),i[4]; s.push(not f and i[4]) 
    elseif n==2 then local f,g,e; e,i[4],f = s.pop(),s.pop(),i[4]; g=not f and i[4]; s.push(g) 
      if g then quickApp:cancel(i[5]) i[5]=quickApp:post(function() i[4]=nil end,e) end
    else local f; i[4],f=os.date("%x"),i[4] or ""; s.push(f ~= i[4]) end
  end
  instrc['enable'] = function(s,n,e,_) 
    if n == 0 then fibaro.EM.enable(e.rule) s.push(true) return end
    local t,g = s.pop(),false; if n==2 then g,t=t,s.pop() end 
    s.push(fibaro.EM.enable(t,g)) 
  end
  instrc['disable'] = function(s,n,e,_) 
    if n == 0 then fibaro.EM.disable(e.rule) s.push(true) return end
    s.push(fibaro.EM.disable(s.pop())) 
  end
  instrc['post'] = function(s,n,ev) local e,t=s.pop(),nil; if n==2 then t=e; e=s.pop() end s.push(quickApp:post(e,t,ev.rule)) end
  instrc['subscribe'] = function(s,_,_) quickApp:subscribe(s.pop()) s.push(true) end
  instrc['publish'] = function(s,n,_) local e,t=s.pop(),nil; if n==2 then t=e; e=s.pop() end quickApp:publish(e,t) s.push(e) end
  instrc['remote'] = function(s,n,_) _assert(n==2,"Wrong number of args to 'remote/2'"); 
    local e,u=s.pop(),s.pop(); 
    quickApp:postRemote(u,e) 
    s.push(true) 
  end
  instrc['cancel'] = function(s,_) quickApp:cancel(s.pop()) s.push(nil) end
  instrc['add'] = function(s,_) local v,t=s.pop(),s.pop() table.insert(t,v) s.push(t) end
  instrc['remove'] = function(s,_) local v,t=s.pop(),s.pop() table.remove(t,v) s.push(t) end
  instrc['again'] = function(s,n,e) 
    local v = n>0 and s.pop() or math.huge
    e.rule._again = (e.rule._again or 0)+1
    if v > e.rule._again then setTimeout(function() e.rule.start(e.rule._event) end,0) else e.rule._again,e.rule._event = nil,nil end
    s.push(e.rule._again or v)
  end
  instrc['trueFor'] = function(s,_,e,i)
    local val,time = s.pop(),s.pop()
    e.rule._event = e.event
    local flags = i[5] or {}; i[5]=flags
    if val then
      if flags.expired then 
        s.push(val); 
        flags.expired=nil;
        return 
      end
      if flags.timer then s.push(false); return end
      flags.timer = setTimeout(function() 
          --  Event._callTimerFun(function()
          flags.expired,flags.timer=true,nil; 
          quickApp:post({type='trueFor',stop=true,expired=true,rule=e.rule,_sh=true})
          e.rule.start(e.rule._event) 
          --      end)
        end,1000*time);
      quickApp:post({type='trueFor',start=true,rule=e.rule,_sh=true})
      s.push(false); return
    else
      if flags.timer then 
        flags.timer=clearTimeout(flags.timer)
        quickApp:post({type='trueFor',stop=true,rule=e.rule,_sh=true})
      end
      s.push(false)
    end
  end

  local compConst = compiler.hooks.compConst
  local function compileInstr(code,exp,...)
    local args,comps = {...},{}
    for _,e in ipairs(args) do comps[#comps+1]=compConst(e,code) end
    code.emit(exp,#args,table.unpack(comps))
  end

  for i,f in pairs(instr) do compiler.hooks.addInstr(i,f) end
  for i,f in pairs(instrc) do builtins[i]=true compiler.hooks.addInstr(i,f,compileInstr) end

------------ Marshal functions (for fibaro.getGlobalVariable and fibaro.setGlobalVariable -------

  local marshalBool={['true']=true,['True']=true,['TRUE']=true,['false']=false,['False']=false,['FALSE']=false}
  function compiler.hooks.marshallTo(val)
    if _MARSHALL then if type(val)=='table' then val=json.encode(val) else val = tostring(val) end end
    return val
  end
  function compiler.hooks.marshallFrom(v)
    if not _MARSHALL then return v elseif v==nil then return v end
    local fc = v:sub(1,1)
    if fc == '[' or fc == '{' then local s,t = pcall(json.decode,v); if s then return t end end
    if tonumber(v) then return tonumber(v)
    elseif marshalBool[v ]~=nil then return marshalBool[v ] end
    local s,t = pcall(toTime,v); return s and t or v
  end
end

