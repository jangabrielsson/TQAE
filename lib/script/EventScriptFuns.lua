EVENTSCRIPT = EVENTSCRIPT or {}
EVENTSCRIPT.builtins = EVENTSCRIPT.builtins or {}

function EVENTSCRIPT.setupFuns()
  local compiler = EVENTSCRIPT.compiler
  local builtins = EVENTSCRIPT.builtins
  local fmt = string.format

  local util = fibaro.utils
  local midnight,toTime = fibaro.midnight,util.toTime
  local function _assert(t,f,...) if not t then error(fmt(f,...)) end end
  local fibaroCall,fibaroGet,fibaroGetValue,getProp,setProp

  EVENTSCRIPT.fibaro = EVENTSCRIPT.fibaro or {}
  function EVENTSCRIPT.fibaro.setup()
    fibaroCall = EVENTSCRIPT.fibaro.call or fibaro.call
    fibaroGet = EVENTSCRIPT.fibaro.get or fibaro.get
    fibaroGetValue = EVENTSCRIPT.fibaro.getValue or fibaro.getValue
  end
  EVENTSCRIPT.fibaro.setup()

  local virtualDevices,virtualDeviceNumber={},100000
  function EVENTSCRIPT.vDev(name,id)
    if id == nil then id = virtualDeviceNumber; virtualDeviceNumber=virtualDeviceNumber+1 end
    local self = {id = id, props={}, name = fmt("<vdev:%s",id) }
    virtualDevices[id]=self
    function self:__tostring() return self.name end
    function self:updateProp(prop,val)
      if self.props[prop]~=val then
        self.props[prop]=val
        fibaro.post({type='device',id=self.id,property='value',value=val}) 
      end
    end
    function self:getProp(prop) return nil end
    function self:setProp(prop,value) end    
    return self.id,self
  end

  local resolvedDevices,cachedTypes,skips={},{},{lastBreached=true,typeTemplateInitialized=true,apiVersion=true,useEmbededView=true}
  local function resolveDevice(id)
    if not resolvedDevices[id] then
      local d = __fibaro_get_device(id)
      if not d then return id end
      resolvedDevices[id]=d.type
      if not cachedTypes[d.type] then
        local p = d.properties; 
        for k,v in pairs(p) do if skips[k] or type(v)=='table' then p[k]=nil else p[k]=type(v) end end end
        cachedTypes[d.type] = {props=p,actions=d.actions,isQA=qa}
      end
    end
    return id
  end
  
  local function mapAnd(l,prop,e)
    if #l==0 then return true else for _,id in ipairs(l) do if not getProp(id,prop,e) then return false end end end
    return true
  end

  local function mapOr(l,prop,e)
    if #l==0 then return false else for _,id in ipairs(l) do if getProp(id,prop,e) then return true end end end
    return false
  end

  local function mapC(l,prop,e) local r = {} for _,id in ipairs(l) do r[#r+1]=getProp(id,prop,e) end return r end 
  local function mapF(l,prop,e) for _,id in ipairs(l) do getProp(id,prop,e) end return true end 

  local function userLogFunction(fm,...)
    local args,t1,t0,str,c1 = {...},__TAG,__TAG
    str = #args==0 and fm or fmt(fm,...)
    str = str:gsub("(#T:)(.-)(#)",function(_,t) t1=t return "" end)
    str = str:gsub("(#C:)(.-)(#)",function(_,c) c1=c return "" end)
    if c1 then str=fmt("<font color=%s>%s</font>",c1,str) end
    __TAG = t1; quickApp:trace(str); __TAG = t0
    return str
  end

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

  local function BN(x) if type(x)=='boolean' then return x and 1 or 0 else return x end end
  local get = fibaroGet
  local function on(id,prop) return BN(fibaroGet(id,prop)) > 0 end
  local function off(id,prop) return BN(fibaroGet(id,prop)) == 0 end
  local function last(id,prop) local _,t=fibaroGet(id,prop); return t and os.time()-t or 0 end
  local function cce(id,_,e) e=e.event; return e.type=='device' and e.property=='centralSceneEvent'and e.id==id and e.value or {} end
  local function ace(id,_,e) e=e.event; return e.type=='device' and e.property=='accessControlEvent' and e.id==id and e.value or {} end
  local function sae(id,_,e) e=e.event; return e.type=='device' and e.property=='sceneActivationEvent' and e.id==id and e.value.sceneId end
  local function profile(id,_) return api.get("/profiles/"..id.."?showHidden=true") end

  local function setProfile(id,_,val) if val then fibaro.profile("activateProfile",id) end return val end
  local function setState(id,cmd,val) fibaroCall(id,"updateProperty","state",val); return val end
  local function setProps(id,cmd,val) fibaroCall(id,"updateProperty",cmd,val); return val end
  local function call(id,cmd) fibaroCall(id,cmd); return true end
  local function set(id,cmd,val) fibaroCall(id,cmd,val); return val end
  local function pushMsg(id,cmd,val) fibaro.alert(cmd,{id},val,false); return val end
  local function set2(id,cmd,val) fibaroCall(id,cmd,table.unpack(val)); return val end
  local function dim2(id,_,val) Util.dimLight(id,table.unpack(val)) end --sec,dir,step,curve,start,stop)
  local function child(id,_) for _,c in pairs(quickApp.childDevices) do if c.eid==id then return c end end return nil end

  local getFuns={}
  getFuns.value={method=get,prop='value',red=false,trigger=true}
  getFuns.state={method=get,prop='state',red=false,trigger=true}
  getFuns.bat={method=get,prop='batteryLevel',red=false,trigger=true}
  getFuns.power={method=get,prop='power',red=false,trigger=true}
  getFuns.isOn={method=on,prop='value',red=mapOr,trigger=true}
  getFuns.isOff={method=off,prop='value',red=mapAnd,trigger=true}
  getFuns.isAllOn={method=on,prop='value',red=mapAnd,trigger=true}
  getFuns.isAnyOff={method=off,prop='value',red=mapOr,trigger=true}
  getFuns.last={method=last,prop='value',red=false,trigger=true}
  getFuns.alarm={method=alarm,prop='alarm',red=false,trigger=true}
  getFuns.armed={method=function(id) return gp(id).armed end,prop='armed',red=mapOr,trigger=true}
  getFuns.allArmed={method=function(id) return gp(id).armed end,prop='armed',red=mapAnd,trigger=true}
  getFuns.disarmed={method=function(id,_,_) return not gp(id).armed end,prop='armed',red=mapAnd,trigger=true}
  getFuns.anyDisarmed={method=function(id,_,_) return not gp(id).armed end,prop='armed',red=mapOr,trigger=true}
  getFuns.alarmBreached={method=function(id) return gp(id).breached end,prop='breached',red=mapOr,trigger=true}
  getFuns.alarmSafe={method=function(id) return not gp(id).breached end,prop='breached',red=mapAnd,trigger=true}
  getFuns.allAlarmBreached={method=function(id) return gp(id).breached end,prop='breached',red=mapAnd,trigger=true}
  getFuns.anyAlarmSafe={method=function(id) return not gp(id).breached end,prop='breached',red=mapOr,trigger=true}
  getFuns.willArm={method=function(id) return armedPs[id] end,prop='willArm',red=mapOr,trigger=true}
  getFuns.allWillArm={method=function(id) return armedPs[id] end,prop='willArm',red=mapAnd,trigger=true}
  getFuns.child={method=child,prop="",red=false,trigger=false}
  getFuns.profile={method=profile,prop='profile',red=false,trigger=false}
  getFuns.scene={method=sae,prop='sceneActivationEvent',red=false,trigger=true}
  getFuns.access={method=ace,prop='accessControlEvent',red=false,trigger=true}
  getFuns.central={method=cce,prop='centralSceneEvent',red=false,trigger=true}
  getFuns.safe={method=off,prop='value',red=mapAnd,trigger=true}
  getFuns.breached={method=on,prop='value',red=mapOr,trigger=true}
  getFuns.isOpen={method=on,prop='value',red=mapOr,trigger=true}
  getFuns.isClosed={method=off,prop='value',red=mapAnd,trigger=true}
  getFuns.lux={method=get,prop='value',red=false,trigger=true}
  getFuns.volume={method=get,prop='volume',red=false,trigger=true}
  getFuns.position={method=get,prop='position',red=false,trigger=true}
  getFuns.temp={method=get,prop='value',red=false,trigger=true}
  getFuns.coolingThermostatSetpoint={method=get,prop='coolingThermostatSetpoint',red=false,trigger=true}
  getFuns.coolingThermostatSetpointCapabilitiesMax={method=get,prop='coolingThermostatSetpointCapabilitiesMax',red=false,trigger=true}
  getFuns.coolingThermostatSetpointCapabilitiesMin={method=get,prop='coolingThermostatSetpointCapabilitiesMin',red=false,trigger=true}
  getFuns.coolingThermostatSetpointFuture={method=get,prop='coolingThermostatSetpointFuture',red=false,trigger=true}
  getFuns.coolingThermostatSetpointStep={method=get,prop='coolingThermostatSetpointStep',red=false,trigger=true}
  getFuns.heatingThermostatSetpoint={method=get,prop='heatingThermostatSetpoint',red=false,trigger=true}
  getFuns.heatingThermostatSetpointCapabilitiesMax={method=get,prop='heatingThermostatSetpointCapabilitiesMax',red=false,trigger=true}
  getFuns.heatingThermostatSetpointCapabilitiesMin={method=get,prop='heatingThermostatSetpointCapabilitiesMin',red=false,trigger=true}
  getFuns.heatingThermostatSetpointFuture={method=get,prop='heatingThermostatSetpointFuture',red=false,trigger=true}
  getFuns.heatingThermostatSetpointStep={method=get,prop='heatingThermostatSetpointStep',red=false,trigger=true}
  getFuns.thermostatFanMode={method=get,prop='thermostatFanMode',red=false,trigger=true}
  getFuns.thermostatFanOff={method=get,prop='thermostatFanOff',red=false,trigger=true}
  getFuns.thermostatMode={method=get,prop='thermostatMode',red=false,trigger=true}
  getFuns.thermostatModeFuture={method=get,prop='thermostatModeFuture',red=false,trigger=true}
  getFuns.on={method=call,prop='turnOn',red=mapF,trigger=true}
  getFuns.off={method=call,prop='turnOff',red=mapF,trigger=true}
  getFuns.play={method=call,prop='play',red=mapF,trigger=false}
  getFuns.pause={method=call,prop='pause',red=mapF,trigger=false}
  getFuns.open={method=call,prop='open',red=mapF,trigger=true}
  getFuns.close={method=call,prop='close',red=mapF,trigger=true}
  getFuns.stop={method=call,prop='stop',red=mapF,trigger=true}
  getFuns.secure={method=call,prop='secure',red=mapF,trigger=false}
  getFuns.unsecure={method=call,prop='unsecure',red=mapF,trigger=false}
  getFuns.isSecure={method=on,prop='secured',red=mapAnd,trigger=true}
  getFuns.isUnsecure={method=off,prop='secured',red=mapOr,trigger=true}
  getFuns.name={method=function(id) return fibaro.getName(id) end,prop=false,red=false,trigger=false}
  getFuns.HTname={method=function(id) return Util.reverseVar(id) end,prop=false,red=false,trigger=false}
  getFuns.roomName={method=function(id) return fibaro.getRoomNameByDeviceID(id) end,prop=false,red=false,trigger=false}
  getFuns.trigger={method=function() return true end,prop='value',red=false,trigger=true}
  getFuns.time={method=get,prop='time',red=false,trigger=true}
  getFuns.manual={method=function(id) return quickApp:lastManual(id) end,prop='value',red=false,trigger=true}
  getFuns.start={method=function(id) return fibaro.scene("execute",{id}) end,prop="",red=mapF,trigger=false}
  getFuns.kill={method=function(id) return fibaro.scene("kill",{id}) end,prop="",red=mapF,trigger=false}
  getFuns.toggle={method=call,prop='toggle',red=mapF,trigger=true}
  getFuns.wake={method=call,prop='wakeUpDeadDevice',red=mapF,trigger=true}
  getFuns.removeSchedule={method=call,prop='removeSchedule',red=mapF,trigger=true}
  getFuns.retryScheduleSynchronization={method=call,prop='retryScheduleSynchronization',red=mapF,trigger=true}
  getFuns.setAllSchedules={method=call,prop='setAllSchedules',red=mapF,trigger=true}
  getFuns.levelIncrease={method=call,prop='startLevelIncrease',red=mapF,trigger=false}
  getFuns.levelDecrease={method=call,prop='startLevelDecrease',red=mapF,trigger=false}
  getFuns.levelStop={method=call,prop='stopLevelChange',red=mapF,trigger=false}

  local setFuns={}
  setFuns.R={method=set,cmd='setR'}
  setFuns.G={method=set,cmd='setG'}
  setFuns.B={method=set,cmd='setB'}
  setFuns.W={method=set,cmd='setW'}
  setFuns.value={method=set,cmd='setValue'}
  setFuns.state={method=setState,cmd='setState'}
  setFuns.alarm={method=setAlarm,cmd='setAlarm'}
  setFuns.armed={method=setAlarm,cmd='setAlarm'}
  setFuns.profile={method=setProfile,cmd='setProfile'}
  setFuns.time={method=set,cmd='setTime'}
  setFuns.power={method=set,cmd='setPower'}
  setFuns.targetLevel={method=set,cmd='setTargetLevel'}
  setFuns.interval={method=set,cmd='setInterval'}
  setFuns.mode={method=set,cmd='setMode'}
  setFuns.setpointMode={method=set,cmd='setSetpointMode'}
  setFuns.defaultPartyTime={method=set,cmd='setDefaultPartyTime'}
  setFuns.scheduleState={method=set,cmd='setScheduleState'}
  setFuns.color={method=set2,cmd='setColor'}
  setFuns.volume={method=set,cmd='setVolume'}
  setFuns.position={method=set,cmd='setPosition'}
  setFuns.positions={method=setProps,cmd='availablePositions'}
  setFuns.mute={method=set,cmd='setMute'}
  setFuns.thermostatSetpoint={method=set2,cmd='setThermostatSetpoint'}
  setFuns.thermostatMode={method=set,cmd='setThermostatMode'}
  setFuns.heatingThermostatSetpoint={method=set,cmd='setHeatingThermostatSetpoint'}
  setFuns.coolingThermostatSetpoint={method=set,cmd='setCoolingThermostatSetpoint'}
  setFuns.thermostatFanMode={method=set,cmd='setThermostatFanMode'}
  setFuns.schedule={method=set2,cmd='setSchedule'}
  setFuns.dim={method=dim2,cmd='dim'}
  setFuns.msg={method=pushMsg,cmd='push'}
  setFuns.defemail={method=set,cmd='sendDefinedEmailNotification'}
  setFuns.btn={method=set,cmd='pressButton'} -- ToDo: click button on QA?
  setFuns.email={method=function(id,_,val) local h,m = val:match("(.-):(.*)"); fibaro.alert('email',{id},val) return val end,cmd=""}
  setFuns.start={method=function(id,_,val) 
      if isEvent(val) then quickApp:postRemote(id,val) else fibaro.scene("execute",{id},val) return true end 
    end,cmd=""}

  for p,v in pairs(getFuns) do assert(v.method~=nil and v.prop~=nil and v.red~=nil and v.trigger~=nil,"Bad "..p) end
  for p,v in pairs(setFuns) do assert(v.method~=nil and v.cmd~=nil,"Bad "..p) end

  EVENTSCRIPT.getFuns=getFuns
  EVENTSCRIPT.setFuns=setFuns


  local getArg,peekArg = compiler.hooks.getArg,compiler.hooks.peekArg
  local instr,instrc={},{}
  local function getVargs(i,s)
    local args = {}
    for j=i[2]+2,3,-1 do args[j-2]=getArg(i[j],s) end
    return table.unpack(args)
  end
  local function getNargs(i,s)
    if type(peekArg(i[3],s)) == 'table' then return table.unpack(getArg(i[3],s)) else return getVargs(i,s) end
  end

  function getProp(id,prop,e)
    local gf = getFuns[prop]
    if type(id)=='table' then
      if gf.red then return gf.red(id,prop,e) else return mapC(id,prop,e) end
    elseif virtualDevices[id] then 
      return virtualDevices[id]:getProp(prop,e)
    else
      if gf then return gf.method(id,gf.prop,e)
      else return fibaroGetValue(id,prop) end
    end
  end

  function setProp(ids,prop,value)
    local sf = setFuns[prop]
    if type(ids)=='table' then
      local r = {}
      for _,id in ipairs(ids) do
        r[#r+1]=setProp(id,prop,value)
      end
      return r
    elseif virtualDevices[ids] then virtualDevices[ids]:setProp(prop,value) return value
    else
      if sf then value = sf.method(ids,sf.cmd,value)
      else fibaroCall(ids,'updateProperty',prop,value) end
      return value
    end
  end

  function EVENTSCRIPT.addPropHandler(prop,get,set)
    getFuns[prop]=get
    setFuns[prop]=set
  end

  ------------- EventScript instructions

  instr['getprop']= function(i,s,env)
    local prop,id = i[2],getArg(i[3],s)
    s.push(getProp(id,prop,env.event))
  end

  instr['setprop']= function(i,s,env) 
    local prop,id,value = i[2],getArg(i[3],s),getArg(i[4],s)
    s.push(setProp(id,prop,value))
  end

  instr['%header'] = function(i,st,env)
    local f = env.opts and env.opts.headerFun
    if f then st.push(f(env,st.pop())) else st.push(st.pop()) end
  end
  instr['%body'] = function(i,st,env)
    local f = env.opts and env.opts.bodyFun
    if f then st.push(f(env,st.pop())) else st.push(st.pop()) end
  end

  instr['len'] = function(i,st,env) st.push(#st.pop()) end

  local function log(m,t)
    print(m,fmt("%02d:%02d:%02d",t//3600,t//60 % 60, t % 60))
    return t
  end

  instr['daily'] = function(i,s,env)
    local v,e,isTrue = s.pop(),env.env,false
    local now,rnow,catch,pCatch,rule = e.event.now,os.time()-fibaro.midnight(),e.event.catch,false,e.rule
    rule.timers = rule.timers or {}
    v = type(v)~='table' and {v} or v
    for _,t in ipairs(v) do
      if t ~= math.maxinteger then
        if rule.timers[t] then if t~= now then fibaro.cancel(rule.timers[t]) end rule.timers[t]=nil end
        if t > now then
          rule.timers[t] = fibaro.post({type='%daily', rule=e.event.rule, now=t, _sh=true},math.max(0,t-rnow))
        elseif t <= now then
          pCatch = true
          if t==now then isTrue = true end
          rule.timers[t] = fibaro.post({type='%daily', rule=e.event.rule, now=t, _sh=true},t-rnow+24*3600)    
        end
      end
    end
    isTrue = isTrue or pCatch and catch  -- catchup
    s.push(isTrue)
  end
  instr['interv'] = function(i,s,env) 
    local v,e,isTrue = s.pop(),env.env,false
    local nxt = e.event.nxt + math.abs(v)
    fibaro.post({type='%interv', rule=e.event.rule, nxt=nxt, _sh=true},nxt-os.time())
    s.push(true)
  end

--  local simpleFuns={num=tonumber,str=tostring,idname=Util.reverseVar,time=toTime,['type']=type,
--    tjson=safeEncode,fjson=json.decode}
--  for n,f in pairs(simpleFuns) do instr[n]=function(s,_,_,_) return s.push(f(s.pop())) end end

  local reservedVars = {
    "sunset","sunrise","midnight","dawn","dusk","now","wnum","env"
  }
  for _,n in ipairs(reservedVars) do compiler.hooks.reservedVars[n]=true end

  instr['env']=function(i,s,env) s.push(env.env) end
  instr['sunset']=function(i,s) s.push(toTime(fibaro.getValue(1,'sunsetHour'))) end
  instr['sunrise']=function(i,s) s.push(toTime(fibaro.getValue(1,'sunriseHour'))) end
  instr['midnight']=function(i,s) s.push(midnight()) end
  instr['dawn']=function(i,s) s.push(toTime(fibaro.getValue(1,'dawnHour'))) end
  instr['dusk']=function(i,s) s.push(toTime(fibaro.getValue(1,'duskHour'))) end
  instr['now']=function(i,s) s.push(os.time()-midnight()) end
  instr['wnum']=function(i,s) s.push(fibaro.getWeekNumber(os.time())) end
  instrc['betw'] = function(i,s) local t2,t1,time=getArg(i[4],s),getArg(i[3],s),os.time()
    _assert(tonumber(t1) and tonumber(t2),"Bad arguments to between '...', '%s' '%s'",t1 or "nil", t2 or "nil")
    if t1  > 24*60*60 then
      s.push(t1 <= time and t2 >= time)
    else
      local now = time-midnight()
      if t1<=t2 then s.push(t1 <= now and now <= t2) else s.push(now >= t1 or now <= t2) end 
    end
  end

--  instrc['wait']=function(i,s) s.push(midnight()+getArg(i[3],s)) end
  instrc['%today']=function(i,s) s.push(midnight()+getArg(i[3],s)) end
  instrc['%nexttime']=function(i,s) local x = getArg(i[3],s); local t=x+midnight(); s.push(t >= os.time() and t or t+24*3600) end
  instrc['%plustime']=function(i,s) s.push(os.time()+getArg(i[3],s)) end
  instrc['HM'] = function(i,s) local t = getArg(i[3],s); s.push(os.date("%H:%M",t < os.time() and t+midnight() or t)) end
  instrc['HMS'] = function(i,s) local t = getArg(i[3],s); s.push(os.date("%H:%M:%S",t < os.time() and t+midnight() or t)) end
  instrc['sign'] = function(i,s) s.push(tonumber(getArg(i[3],s)) < 0 and -1 or 1) end
  instrc['rnd'] = function(i,s) 
    local n,mi,ma=i[2] 
    if n>1 then ma,mi=getArg(i[4],s),getArg(i[3],s) else mi,ma=1,getArg(i[3],s) end
    s.push(math.random(mi,ma)) 
  end
  instrc['round'] = function(i,s) local v=getArg(i[3],s); s.push(math.floor(v+0.5)) end
  instrc['sum'] = function(i,s) local res=0 for _,x in ipairs({getNargs(i,s)}) do res=res+x end s.push(res) end
  instrc['average'] = function(i,s) local m,res={getNargs(i,s)},0 for _,x in ipairs(m) do res=res+x end s.push(res/#m) end
  instrc['size'] = function(i,s) s.push(#(getArg(i[3],s))) end
  instrc['log'] = function(i,s) s.push(userLogFunction(getVargs(i,s))) end
  instrc['min'] = function(i,s) s.push(math.min(getNargs(i,s))) end
  instrc['max'] = function(i,s) s.push(math.max(getNargs(i,s))) end
  instrc['sort'] = function(i,s) local a = {getNargs(i,s)}; table.sort(a) s.push(a) end
  instrc['match'] = function(i,s) local a,b=getArg(i[4],s),getArg(i[3],s); s.push(string.match(tostring(b),tostring(a))) end
  instrc['osdate'] = function(i,s) local n=i[2] local t,str = n>1 and getArg(i[4],s) or nil,getArg(i[3],s) s.push(os.date(str,t)) end
  instrc['ostime'] = function(i,s) s.push(os.time()) end
  instrc['fmt'] = function(i,s) s.push(fmt(getNargs(i,s))) end
  instrc['eval'] = function(i,s) s.push(EVENTSCRIPT.evalStr(getArg(i[3],s))) end
  instrc['add'] = function(i,s) 
    local v,t=getArg(i[4],s),getArg(i[3],s) 
    table.insert(t,v) s.push(t) 
  end
  instrc['global'] = function(i,s)  s.push(api.post("/globalVariables/",{name=getArg(i[3],s)})) end
  instrc['listglobals'] = function(i,s) s.push(api.get("/globalVariables/")) end
  instrc['deleteglobal'] = function(i,s) s.push(api.delete("/globalVariables/"..getArg(i[3],s))) end
  instrc['once'] = function(i,s) 
    local n = i[2]
    if n==1 then local f; i[4],f = s.pop(),i[4]; s.push(not f and i[4]) 
    elseif n==2 then local f,g,e; e,i[4],f = s.pop(),s.pop(),i[4]; g=not f and i[4]; s.push(g) 
      if g then fibaro.cancel(i[5]) i[5]=fibaro.post(function() i[4]=nil end,e) end
    else local f; i[4],f=os.date("%x"),i[4] or ""; s.push(f ~= i[4]) end
  end
  instrc['enable'] = function(i,s,e)
    local n = i[2]
    if n == 0 then fibaro.EM.enable(e.env.rule) s.push(true) return end
    local t,g = s.pop(),false; if n==2 then g,t=t,s.pop() end 
    s.push(fibaro.EM.enable(t,g)) 
  end
  instrc['disable'] = function(i,s,e) 
    local n = i[2]
    if n == 0 then fibaro.EM.disable(e.env.rule) s.push(true) return end
    s.push(fibaro.EM.disable(getArg(i[3],s))) 
  end
  instrc['post'] = function(i,s) s.push(fibaro.post(getVargs(i,s))) end
  instrc['subscribe'] = function(i,s) fibaro.subscribe(getArg(i[3],s)) s.push(true) end
--  instrc['publish'] = function(i,s) local e,t=s.pop(),nil; if n==2 then t=e; e=s.pop() end fibaro.publish(e,t) s.push(e) end
  instrc['remote'] = function(i,s)
    local event,id=getArg(i[4],s),getArg(i[3],s) 
    fibaro.postRemote(id,event) 
    s.push(true) 
  end
  instrc['cancel'] = function(i,s) fibaro.cancel(getArg(i[3],s)) s.push(nil) end
--  instrc['remove'] = function(s,_) local v,t=s.pop(),s.pop() table.remove(t,v) s.push(t) end
  instrc['match_event'] = function(i,s,e)
    local ie,pe,ce = e.env.event,s.pop(),i[5]
    if ce==nil then
      ce=fibaro.EM.compilePattern(pe)
      i[5]=ce
    end
    local vs = fibaro.EM.match(ce,ie)
    if vs then
      e.env.p = {}
      local p = e.env.p
      for k,v in pairs(vs) do p[k]=v end
      s.push(p)
    else s.push(false) end
  end
  instrc['again'] = function(i,s,e) 
    local v = i[2]>0 and getArg(i[3],s) or math.huge
    local rule = e.env.rule
    rule._again = (rule._again or 0)+1
    if v > rule._again then setTimeout(function() rule.start(rule._event) end,0) else rule._again,rule._event = nil,nil end
    s.push(rule._again or v)
  end
  instrc['trueFor'] = function(i,s,e)
    local val,time = getArg(i[4],s),getArg(i[3],s)
    local rule = e.env.rule
    rule._event = e.env.event
    local flags = i[5] or {}; i[5]=flags
    if val then
      if flags.expired then 
        s.push(val); 
        flags.expired=nil;
        return 
      end
      if flags.timer then s.push(false); return end
      flags.timer = setTimeout(function() 
          flags.expired,flags.timer=true,nil; 
          fibaro.post({type='trueFor',stop=true,expired=true,rule=rule,_sh=true})
          rule.start(rule._event) 
        end,1000*time);
      quickApp:post({type='trueFor',start=true,rule=rule,_sh=true})
      s.push(false); return
    else
      if flags.timer then 
        flags.timer=clearTimeout(flags.timer)
        fibaro.post({type='trueFor',stop=true,rule=e.rule,_sh=true})
      end
      s.push(false)
    end
  end

  local compConst = compiler.hooks.compConst
  local function compileInstr(code,exp,...)
    local args,comps = {...},{}
    for i,e in ipairs(args) do comps[i]=compConst(e,code) end
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

-----------------------------------------------------------------------------  

  EVENTSCRIPT.defvars{
    S1 = {click = 16, double = 14, tripple = 15, hold = 12, release = 13},
    S2 = {click = 26, double = 24, tripple = 25, hold = 22, release = 23},
    catch = math.huge,
    defvars=EVENTSCRIPT.defvars,
    mapvars=EVENTSCRIPT.reverseMapDef,
    print = function(...) quickApp:printTagAndColor(...) end,
    QA = quickApp,
    fopp =  function() print("foo") end,

    setSceneEnabled = fibaro.setSceneEnabled, --(sceneID,enabled)
    isSceneEnabled = fibaro.isSceneEnabled, --(sceneID)
    getSceneRunConfig = fibaro.getSceneRunConfig, --(sceneID)
    setSceneRunConfig = fibaro.setSceneRunConfig, --(sceneID,runConfig)
    getAllGlobalVariables = fibaro.getAllGlobalVariables, --()                                  -- Returns list of all global variable names
    createGlobalVariable= fibaro.createGlobalVariable, --(name,value,options)  -- Create a global variable
    deleteGlobalVariable = fibaro.deleteGlobalVariable, --(name)                          -- Delete a global variable
    existGlobalVariable = fibaro.existGlobalVariable, --(name)                             -- Check if a global variable exists
    getGlobalVariableType = fibaro.getGlobalVariableType, --(name)                      -- Get the type of a global variable
    getGlobalVariableLastModified= fibaro.getGlobalVariableLastModified, --(name)        -- Get last time global variable was modified
    getAllCustomEvents = fibaro.getAllCustomEvents, --()                                     -- Returns list of all custom events names
    createCustomEvent = fibaro.createCustomEvent, --(name,userDescription)  -- Create a custom Event
    deleteCustomEvent  = fibaro.deleteCustomEvent, --(name)                              -- Delete a custom Event
    existCustomEvent = fibaro.existCustomEvent, --(name)
    activeProfile= fibaro.activeProfile, --(id)
    profileIdtoName = fibaro.profileIdtoName, --(pid)
    profileNameToId = fibaro.profileNameToId, --(name)
    partitionIdToName = fibaro.partitionIdToName, --(pid)
    partitionNameToId = fibaro.partitionNameToId, --(name)
    getBreachedDevicesInPartition = fibaro.getBreachedDevicesInPartition, --(pid)
    getAllPartitions = fibaro.getAllPartitions, --()
    getArmedPartitions = fibaro.getArmedPartitions, --()
    getActivatedPartitions = fibaro.getActivatedPartitions, --()
    activatedPartitions = fibaro.activatedPartitions, --(callback)      -- Calls callback when a partition is activated (but not armed yet)
    getBreachedPartitions = fibaro.getBreachedPartitions, --()
    getAlarmDevices = fibaro.getAlarmDevices, --()
    weather = fibaro.weather, --.temperature()
--    weather = fibaro.weather.temperatureUnit()
--    weather = fibaro.weather.humidity()
--    weather = fibaro.weather.wind()
--    weather = fibaro.weather.weatherCondition()
--    weather = fibaro.weather.conditionCode()
    getClimateMode = fibaro.getClimateMode,  --(id)   -- Returns mode - "Manual", "Vacation", "Schedule"
    climateModeMode = fibaro.climateModeMode, --(id,mode)  -- Returns the currents mode "mode", or sets it - "Auto", "Off", "Cool", "Heat"
    setClimateZoneToScheduleMode = fibaro.setClimateZoneToScheduleMode,--(id)              -- Set zone to scheduled mode
    setClimateZoneToManualMode =  fibaro.setClimateZoneToManualMode,--(id, mode, time, heatTemp, coolTemp) 
    -- Set zone to manual, incl. mode, time ( secs ), heat and cool temp
    setClimateZoneToVacationMode = fibaro.setClimateZoneToVacationMode,--(id, mode, start, stop, heatTemp, coolTemp)
    -- Set zone to vacation, incl. mode, start (secs from now), stop (secs from now), heat and cool temp

    postGeofenceEvent = fibaro.postGeofenceEvent, --(userId,locationId,geofenceAction) -- post a GeofenceEvent into the HC3 event mechanism
    postCentralSceneEvent = fibaro.postCentralSceneEvent, --(keyId,keyAttribute) -- post a CentralSceneEvent into the HC3 event mechanism
    HC3version = fibaro.HC3version, --(version)    -- Returns or tests firmware version of HC3
    getIPaddress = fibaro.getIPaddress, --(name)     -- Returns IP address of HC3
  }
end