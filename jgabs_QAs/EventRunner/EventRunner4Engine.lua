--luacheck: globals ignore _debugFlags hc3_emulator Util Rule utils
--luacheck: globals ignore QuickApp QuickAppChild quickApp fibaro json __TAG net api class __print netSync Nodered
--luacheck: globals ignore __fibaro_get_device setTimeout clearTimeout setInterval clearInterval __fibaro_get_device_property table
--luacheck: ignore 212/self
--luacheck: ignore 432/self

QuickApp.E_SERIAL,QuickApp.E_VERSION,QuickApp.E_FIX = "UPD896661234567892",0.994,"N/A"

--local _debugFlags = { triggers = true, post=true, rule=true, fcall=true  }
_debugFlags = _debugFlags or {}
_debugFlags.fcall=true
_debugFlags.post = true
_debugFlags.rule=true

Util,Rule = nil,Rule or {}
local isError, throwError, Debug
local _assert, _assertf, tojson, _traceInstrs
local _RULELOGLENGTH, _MIDNIGHTADJUST = nil,nil

------------------- EventSupport - Don't change! --------------------
local Toolbox_Module  = {}
local Module    = Toolbox_Module
local _MARSHALL = true
local format    = string.format
local function trimError(err) 
  if type(err)=='string' and not _debugFlags.extendedErrors then return err:gsub("(%[.-%]:%d+:)","") else return err end 
end

----------------- Module device support -----------------------
Module.device = { name="ER Device", version="0.2"}
function Module.device.init(selfM)
  if Module.device.inited then return Module.device.inited end
  Module.device.inited = true

  local dev = { deviceID = selfM.id }

  function selfM:FEventRunner4(ev)
    self:post({type='UI',id=ev.deviceId,name=ev.elementName,event=ev.eventType,value=ev.values})
  end

  -- Patch fibaro.call to track manual switches
  local lastID,switchMap = {},{}
  local oldFibaroCall = fibaro.call
  function fibaro.call(id,action,...)
    if ({turnOff=true,turnOn=true,on=true,toggle=true,off=true,setValue=true})[action] then lastID[id]={script=true,time=os.time()} end
    if action=='setValue' and switchMap[id]==nil then
      local actions = (__fibaro_get_device(id) or {}).actions or {}
      switchMap[id] = actions.turnOff and not actions.setValue
    end
    if action=='setValue' and switchMap[id] then return oldFibaroCall(id,({...})[1] and 'turnOn' or 'turnOff') end
    return oldFibaroCall(id,action,...)
  end

  local function lastHandler(ev)
    if ev.type=='device' and ev.property=='value' then
      local last = lastID[ev.id]
      local _,t = fibaro.get(ev.id,'value')
      --if last and last.script then print("T:"..(t-last.time)) end
      if not(last and last.script and t-last.time <= 2) then
        lastID[ev.id]={script=false, time=t}
      end
    end
  end

  fibaro.registerSourceTriggerCallback(lastHandler)
  function selfM.lastManual(_,id)
    local last = lastID[id]
    if not last then return -1 end
    return last.script and -1 or os.time()-last.time
  end

  local childID = 'ChildID'
  local classID = 'ClassName'
  local defChildren

  local children = {}
  local undefinedChildren = {}
  local createChild = QuickApp.createChildDevice
  class 'QwikAppChild'(QuickAppChild)

  function QwikAppChild:__init(device) 
    QuickAppChild.__init(self, device)
    self:debug("Instantiating object ",device.name)
    local uid = self:getVariable(childID) or ""
    self.uid = uid
    if defChildren[uid] then
      children[uid]=self               -- Keep table with all children indexed by uid. uid is unique.
    else                               -- If uid not in our children table, we will remove this child
      undefinedChildren[#undefinedChildren+1]=self.id 
    end
  end

  function QuickApp:createChildDevice(uid,props,interfaces,className)
    __assert_type(uid,'string')
    __assert_type(className,'string')
    props.initialProperties = props.initialProperties or {}
    local qas = {{name=childID,value=uid},{name=classID,value=className}}
    props.initialProperties.quickAppVariables = qas
    props.initialInterfaces = interfaces
    self:debug("Creating device ",props.name)
    return createChild(self,props,_G[className])
  end

  local function getVar(child,varName)
    for _,v in ipairs(child.properties.quickAppVariables or {}) do
      if v.name==varName then return v.value end
    end
    return ""
  end

  function QuickApp:loadExistingChildren(chs)
    __assert_type(chs,'table')
    local stat,err = pcall(function()
        defChildren = chs
        self.children = children
        function self.initChildDevices() end
        local cdevs,n = api.get("/devices?parentId="..self.id) or {},0 -- Pick up all my children
        for _,child in ipairs(cdevs) do
          local uid = getVar(child,childID)
          local className = getVar(child,classID)
          local childObject = _G[className] and _G[className](child) or QuickAppChild(child)
          self.childDevices[child.id]=childObject
          childObject.parent = self
        end
      end)
    if not stat then self:error("loadExistingChildren:"..err) end
  end

  function QuickApp:createMissingChildren()
    local stat,err = pcall(function()
        for uid,data in pairs(defChildren) do
          if not self.children[uid] then
            local props = {
              name = data.name,
              type = data.type,
            }
            self:createChildDevice(uid,props,data.interfaces,data.className)           
          end
        end
      end)
    if not stat then self:error("createMissingChildren:"..err) end
  end

  function QuickApp:removeUndefinedChildren()
    for _,deviceId in ipairs(undefinedChildren) do -- Remove children not in children table
      self:removeChildDevice(deviceId)
    end
  end

  function QuickApp:initChildren(children)
    self:loadExistingChildren(children)
    self:createMissingChildren()
    self:removeUndefinedChildren()
  end

  local ERchildren = {}
  local function initChildren()
    quickApp:initChildren(ERchildren)
    for uid,c in pairs(quickApp.children) do 
      Util.defvar(uid,c.id)
      Util.defvar(uid.."_D",c)
      local d = api.get("/devices/"..c.id)
      for name,_ in pairs(d.actions) do
        c[name] = function(self,...) quickApp:post({type='UI',action=name,id=c.id,args={}}) end
      end
    end
  end
  local function child(uid,name,typ)
    ERchildren[uid] = {name=name,type=typ,className='QwikAppChild'}
  end
  Util.defvar('child',child)
  Util.defvar('initChildren',initChildren)
  
  return dev
end

----------------- Module utilities ----------------------------
Module.utilities = { name="ER Utilities", version="0.6"}
function Module.utilities.init(QA)
  if Module.utilities.inited then return Module.utilities.inited end
  Module.utilities.inited = true

  QA.color = { banner = 'black', rule='green', info='purple' }
  local self = {}
  local equal=table.equal

  function self.findEqual(tab,obj)
    for _,o in ipairs(tab) do if equal(o,obj) then return true end end
  end

  function isError(e) return type(e)=='table' and e.ERR end
  function throwError(args) args.ERR=true; error(args,args.level) end

  function self.mkStream(tab)
    local p,selfM=0,{ stream=tab, eof={type='eof', value='', from=tab[#tab].from, to=tab[#tab].to} }
    function selfM.next() p=p+1 return p<=#tab and tab[p] or self.eof end
    function selfM.last() return tab[p] or selfM.eof end
    function selfM.peek(n) return tab[p+(n or 1)] or selfM.eof end
    return selfM
  end
  function self.mkStack()
    local p,st,selfM=0,{},{}
    function selfM.push(v) p=p+1 st[p]=v end
    function selfM.pop(n) n = n or 1; p=p-n; return st[p+n] end
    function selfM.popn(n,v) v = v or {}; if n > 0 then local p0 = selfM.pop(); selfM.popn(n-1,v); v[#v+1]=p0 end return v end 
    function selfM.peek(n) return st[p-(n or 0)] end
    function selfM.lift(n) local s = {} for i=1,n do s[i] = st[p-n+i] end selfM.pop(n) return s end
    function selfM.liftc(n) local s = {} for i=1,n do s[i] = st[p-n+i] end return s end
    function selfM.isEmpty() return p<=0 end
    function selfM.size() return p end    
    function selfM.setSize(np) p=np end
    function selfM.set(i,v) st[p+i]=v end
    function selfM.get(i) return st[p+i] end
    function selfM.dump() for i=1,p do print(json.encode(st[i])) end end
    function selfM.clear() p,st=0,{} end
    return selfM
  end

  self._vars = {}
  local _vars = self._vars
  local _triggerVars = {}
  self._triggerVars = _triggerVars
  self._reverseVarTable = {}
  function self.defvar(var,expr) if _vars[var] then _vars[var][1]=expr else _vars[var]={expr} end end
  function self.defvars(tab) for var,val in pairs(tab) do self.defvar(var,val) end end
  function self.defTriggerVar(var,expr) _triggerVars[var]=true; self.defvar(var,expr) end
  function self.triggerVar(v) return _triggerVars[v] end
  function self.reverseMapDef(table) self._reverseMap({},table) end
  function self._reverseMap(path,value)
    if type(value) == 'number' then self._reverseVarTable[tostring(value)] = table.concat(path,".")
    elseif type(value) == 'table' and not value[1] then
      for k,v in pairs(value) do table.insert(path,k); self._reverseMap(path,v); table.remove(path) end
    end
  end
  function self.reverseVar(id) return Util._reverseVarTable[tostring(id)] or id end
  local function isVar(v) return type(v)=='table' and v[1]=='%var' end
  self.isVar = isVar
  function self.isGlob(v) return isVar(v) and v[3]=='glob' end

  self.coroutine = {
    create = function(code,src,env)
      env=env or {}
      env.cp,env.stack,env.code,env.src=1,Util.mkStack(),code,src
      return {state='suspended', context=env}
    end,
    resume = function(co) 
      if co.state=='dead' then return false,"cannot resume dead coroutine" end
      if co.state=='running' then return false,"cannot resume running coroutine" end
      co.state='running' 
      local status = {pcall(Rule.ScriptEngine.eval,co.context)}
      if status[1]==false then return status[2] end
      co.state= status[2]=='suspended' and status[2] or 'dead'
      return true,table.unpack(status[3])
    end,
    status = function(co) return co.state end,
    _reset = function(co) co.state,co.context.cp='suspended',1; co.context.stack.clear(); return co.context end
  }

  local VIRTUALDEVICES = {}
  function self.defineVirtualDevice(id,call,get) VIRTUALDEVICES[id]={call=call,get=get} end
  do
    local oldGet,oldCall = fibaro.get,fibaro.call
    function fibaro.call(id,action,...) local d = VIRTUALDEVICES[id]
      if d and d.call and d.call(id,action,...) then return
      else oldCall(id,action,...) end
    end
    function fibaro.get(id,prop,...) local g = VIRTUALDEVICES[id]
      if g and g.get then 
        local stat,res = g.get(id,prop,...)
        if stat then return table.unpack(res) end
      end
      return oldGet(id,prop,...)
    end
  end

  local NOFTRACE={
    [""]=true,["ER_remoteEvent"]=true,
    ['SUBSCRIBEDEVENT']=true,
    ['SYNCPUBSUB']=true,
  }

  local function patchF(name)
    local oldF,flag = fibaro[name],"f"..name
    fibaro[name] = function(...)
      local args = {...}
      local res = {oldF(...)}
      if _debugFlags[flag] then
        if not NOFTRACE[args[2] or ""] then
          args = #args==0 and "" or json.encode(args):sub(2,-2)
          quickApp:debugf("fibaro.%s(%s) => %s",name,args,#res==0 and "nil" or #res==1 and res[1] or res)
        end
      end
      return table.unpack(res)
    end
  end

  patchF("call")

  function self.strPad(str,args,ch,w)
    ch,w=ch or "-",w or 100
    str = format(str,table.unpack(args or {}))
    str = #str % 2 == 1 and str.." " or str
    local n = #str+2
    local l2=100/2-n/2
    return string.rep(ch,l2).." "..str.." "..string.rep(ch,l2)
  end

  function self.makeBanner(str,args,ch,w) return self.strPad(str,args,ch,w) end
  if hc3_emulator then
    function self.printBanner(str,args,col,ch,w) quickApp:debug(self.makeBanner(str,args,ch,w)) end
  else
    function self.printBanner(str,args,col,ch,w)
      col=col or QA.color.banner
      quickApp:debug(self.htmlTable({format(str,table.unpack(args or {}))},{table="width='100%' border=1 bgcolor='"..col.."'",td="align='center'"}))
    end
  end

  function self.printColorAndTag(tag,color,fmt,...)
    assert(tag and color and fmt,"print needs tag, color, and args")
    local args={...}
    if #args > 0 then
      for i,v in ipairs(args) do if type(v)=='table' then args[i]=tostring(v) end end
      fmt=string.format(fmt,table.unpack(args))
    end
    local t = __TAG
    __TAG = tag or __TAG
    if hc3_emulator or not color then quickApp:trace(fmt) 
    else
      quickApp:trace("<font color="..color..">"..fmt.."</font>") 
    end
    __TAG = t
  end

  function Debug(flag,...) if flag then quickApp:debugf(...) end end

  function _assert(test,msg,...) if not test then error(string.format(msg,...),3) end end
  function _assertf(test,msg,fun) if not test then error(string.format(msg,fun and fun() or ""),3) end end

  local cbr = {}
  function self.asyncCall(errstr,timeout)
    local tag = fibaro.utils.gensym("CBR")
    cbr[tag]={nil,nil,errstr}
    cbr[tag][1]=setTimeout(function() 
        cbr[tag]=nil 
        quickApp:errorf("No response from %s call",errstr)
      end,timeout)
    return tag,{
      ['<cont>']=
      function(cont) 
        cbr[tag][2]=cont 
      end
    }
  end

  function self.receiveAsync(tag,res)
    local cr = cbr[tag] or {}
    if cr[1] then clearTimeout(cr[1]) end
    if cr[2] then 
      local stat,res0 = pcall(function() cr[2](res) end)
      if not stat then quickApp:errorf("Error in %s call - %s",cr[3],res0) end
    end
    cbr[tag]=nil
  end

  self.S1 = {click = "16", double = "14", tripple = "15", hold = "12", release = "13"}
  self.S2 = {click = "26", double = "24", tripple = "25", hold = "22", release = "23"} 

  tojson = json.encodeFast

  local function lastTime(t) return t and os.date("%x-%X",t) or "not triggered" end
  local time2str = fibaro.time2str

  function self.rule2string(ru,ct)
    local pr = fibaro.utils.printBuffer()
    pr:add(ru.doc)
    table.map(function(r) pr:printf("-Interv(%s) =>... [%s]",time2str(r),lastTime(ru.rep.time)) end,ct(ru.reps)) 
    if ru.daily then
      local s = {}
      table.map(function(d) s[#s+1]=d==math.huge and "catchup" or time2str(d) end,ct(ru.dailys.dailys))
      pr:printf("-Daily(%s) =>... [%s]",table.concat(s,","),lastTime(ru.daily.time))
    end
    table.mapkv(function(tr,r) pr:printf("-Trigger(%s) =>... [%s]",tojson(tr),lastTime(r.time)) end,ru.triggers)
    return pr.buffer
  end

  function self.rules2string(...)
    local args = {...}
    if next(args)==nil then args={"all"} end
    local i,r={},{}
    for _,x in ipairs(args) do
      if type(x)=='number' then
        if x > 0 then i[x]=true else r[-x]=true end
      elseif type(x)=='table' then
        for z=x[1],x[2],i[3] or 1 do if z > 0 then i[z]=true else r[-z]=true end end
      elseif x=='all' then
        for id,_ in pairs(Rule._rules) do i[id]=true end
      end
    end
    local i2={}
    for id,_ in pairs(r) do i[id]=nil end
    for id,_ in pairs(i) do i2[#i2+1]=id end
    table.sort(i2)
    local m = {}
    for _,id in pairs(i2) do
      m[#m+1]=Rule._rules[id].rule2str()
    end
    return Util.htmlTable(m,{table="border=1 bgcolor='"..QA.color.rule.."'"})
  end

  function self.printRules(...) print("\nRules:"..self.rules2string(...)) end

  local function maxLen(list) local m = 0 for _,e in ipairs(list) do m=math.max(m,e:len()) end return m end
  if hc3_emulator then 
    function self.htmlTable(list,opts)
      opts = opts or {}
      local pr,cols,rows=fibaro.utils.printBuffer(),{},{}
      for i,e in ipairs(list) do list[i]=type(e)=='table' and e or {e} end
      for i=1,#list do
        for j=1,#list[i] do
          local e = list[i][j]
          local s = e:split("\n")
          list[i][j]=s
          cols[j]=math.max(cols[j] or 0,maxLen(s))
          rows[i]=math.max(rows[i] or 0,#s)
        end
      end
      local s = "+"
      for j=1,#cols do s=s..("-"):rep(cols[j]+2).."+" end -- Create line divider
      pr:add(s)
      for i=1,#list do  -- rows
        for r=1,rows[i] do
          local l = {}
          for j=1,#list[i] do -- cols
            local ll = list[i][j][r] or ""
            l[#l+1]=ll..(" "):rep(cols[j]-ll:len())
            sp=" |"
          end
          pr:add("| "..table.concat(l," | ").." |")
        end
        pr:add(s)
      end
      return "\n"..pr:tostring("\n")
    end
  else
    function self.htmlTable(list,opts)
      opts = opts or {}
      local pr = fibaro.utils.printBuffer(),opts or {}
      pr:printf("<table %s>",opts.table or "")
      for _,l in ipairs(list) do
        pr:printf("<tr %s>",opts.tr or "")
        l = type(l)=='table' and l or {l}
        for _,e in ipairs(l) do
          pr:printf("<td %s>",opts.td or "") pr:add(tostring(e)) pr:add("</td>") 
        end
        pr:add("</tr>")
      end
      pr:add("</table>")
      return pr:tostring()
    end
  end

  local memoryInfo,infoStart = nil,os.time()
  function self.printInfo()
    local pr = fibaro.utils.printBuffer()
    pr:printf("%s, ER uptime:%s hours",os.date("%A, %B %d"),(os.time()-infoStart)//(3600))
    pr:printf("Sunrise:%s,  Sunset:%s",(fibaro.get(1,"sunriseHour")),(fibaro.get(1,"sunsetHour")))
    pr:printf("#Events handled :%-6s,#Events matched:%s",fibaro.EM.stats.tried or 0,fibaro.EM.stats.matched or 0)
    pr:printf("#Rules succeeded:%-6s,#Rules false:%s",fibaro.EM.stats.success or 0,fibaro.EM.stats.fail or 0)
    pr:printf("#Rules error    :%s",fibaro.EM.stats.error or 0)
    collectgarbage("collect")
    local cm = collectgarbage("count")
    memoryInfo = memoryinfo or {cm,cm,cm,cm,cm,cm,cm,cm}
    local m = memoryInfo
    table.insert(memoryInfo,1,collectgarbage("count"))
    table.remove(memoryInfo,9)
    pr:printf("Memory:%.1fkb [%0.f%% %0.f%% %0.f%% %0.f%% %0.f%% %0.f%% %0.f%%]",
      m[1],100*m[1]/m[2],100*m[1]/m[3],100*m[1]/m[4],100*m[1]/m[5],100*m[1]/m[6],100*m[1]/m[7],100*m[1]/m[8])
    print(Util.htmlTable({pr:tostring("\n")},{table="bgcolor='"..QA.color.info.."' width='100%'"}))
  end

  local hourTasks,nextHour,hourRef={}
  local function hourLoop()
    for f,_ in pairs(hourTasks) do pcall(f) end
    nextHour = nextHour+3600
    hourRef = setTimeout(hourLoop,1000*(nextHour-os.time())) 
  end
  function QA:addHourTask(f)
    hourTasks[f]=true
    if hourRef==nil then 
      nextHour = (os.time() // 3600)*3600
      nextHour = nextHour+3600+1
      hourRef = setTimeout(hourLoop,1000*(nextHour-os.time())) 
    end
  end

  Util = self
  return self
end -- Utils

----------------- Autopatch support ---------------------------
Module.autopatch = { name="ER Autopatch", version="0.2"}
function Module.autopatch.init(self)
  if Module.autopatch.inited then return Module.autopatch.inited end
  Module.autopatch.inited = true
  local UpdaterID,UpdateVersion
  function Util.checkForUpdates()
    local updater = api.get("/devices?name=QAUpdater")
    if updater and updater[1] then
      updater = updater[1]
      UpdaterID = updater.id
      local updates = fibaro.getQAVariable(updater.id,"UPDATES")
      if not(updates and type(updates) == 'table') then return end
      for _,up in ipairs(updates) do
        if "UPD"..up.serial == quickApp.E_SERIAL then
          for _,v in ipairs(up.versions) do
            if (v.version - QuickApp.E_VERSION) > 0.0001 then
              UpdateVersion=v.version
              self:post({type='File_update',file=up.name,version=v.version,descr=v.descr,updaterID=UpdaterID})
            end
          end
        end
      end
    else
      self:warning("Please install QAUpdater and name it 'QAUpdater'")
    end
  end

  function Util.updateFile(_)
    if UpdaterID and UpdateVersion then
      fibaro.call(UpdaterID,"updateMe",self.id,UpdateVersion)
    end
  end

end

----------------- Module Extras -------------------------------
Module.extras = { name="ER Extras", version="0.2"}
function Module.extras.init(self)
  if Module.extras.inited then return Module.extras.inited end
  Module.extras.inited = true 
  -- Sunset/sunrise patch -- first time in the day someone asks for sunsethours we calculate and cache
  local _SUNTIMEDAY = nil
  local _SUNTIMEVALUES = {sunsetHour="00:00",sunriseHour="00:00",dawnHour="00:00",duskHour="00:00"}
  Util.defineVirtualDevice(1,nil,function(_,prop)
      if not _SUNTIMEVALUES[prop] then return nil end
      local s = _SUNTIMEVALUES
      local day = os.date("*t").day
      if day ~= _SUNTIMEDAY then
        _SUNTIMEDAY = day
        s.sunriseHour,s.sunsetHour,s.dawnHour,s.duskHour=fibaro.utils.sunCalc()
      end
      return true,{_SUNTIMEVALUES[prop],os.time()}
    end)

  local debugButtons = {
    debugTrigger='Trigger',
    debugPost='Post',
    debugRule='Rule',
  }

  for b,n in pairs(debugButtons) do
    local name = n..":"..(_debugFlags[n:lower()] and "ON" or "OFF")
    self:updateView(b,"text",name)
  end

  self:event({type='UI'},
    function(env)
      local trigger = (debugButtons)[env.event.name]
      if trigger then
        local tname = trigger:lower()
        _debugFlags[tname] = not _debugFlags[tname]
        local name = trigger..":"..(_debugFlags[tname] and "ON" or "OFF")
        self:updateView(env.event.name,"text",name)
        return fibaro.EM.BREAK
      end
    end)

  function self:profileName(id) for _,p in ipairs(api.get("/profiles").profiles) do if p.id == id then return p.name end end end
  function self:profileId(name) for _,p in ipairs(api.get("/profiles").profiles) do if p.name == name then return p.id end end end

  function self:activeProfile(id) 
    if id then
      if type(id)=='string' then id = self:profileId(id) end
      assert(id,"profile.active(id) - no such id/name")
      return api.put("/profiles",{activeProfile=id}) and id
    end
    return api.get("/profiles").activeProfile 
  end

  function self:postCustomEvent(name,descr)
    if descr then 
      if api.get("/customEvents/"..name) then
        api.put("/customEvents",{name=name,userDescription=descr}) 
      else api.post("/customEvents",{name=name,userDescription=descr}) end
    end
    return fibaro.emitCustomEvent(name)
  end

  function self:getCustomEvent(name) return (api.get("customEvents/"..name) or {}).description end 
  function self:deleteCustomEvent(name) return api.delete("customEvents/"..name) end

  Util.defvar('remote',function(id,event,time)
      return self:post(function()
          quickApp:tracef("Remote post to %d %s",id,event)
          self:postRemote(id,event)
        end,time)
    end)

  local function httpCall(url,options,data) 
    local opts = table.copy(options)
    opts.headers = opts.headers or {}
    if opts.type then
      opts.headers["content-type"]=opts.type
      opts.type=nil
    end
    if not opts.headers["content-type"] then
      opts.headers["content-type"] = 'application/json'
    end
    if opts.user or opts.pwd then 
      opts.headers['Authorization']= fibaro.utils.basicAuthorization((opts.user or ""),(opts.pwd or ""))
      opts.user,opts.pwd=nil,nil
    end
    opts.data = data and json.encode(data)
    local tag,res = Util.asyncCall("HTTP",50000)
    net.HTTPClient():request(url,{
        options=opts,
        success = function(res0) Util.receiveAsync(tag,res0) end,
        error = function(res0) Util.receiveAsync(tag,res0) end
      })
    return res
  end

  local http = {}
  function http.get(url,options) options=options or {}; options.method="GET" return httpCall(url,options) end
  function http.put(url,options,data) options=options or {}; options.method="PUT" return httpCall(url,options,data) end
  function http.post(url,options,data) options=options or {}; options.method="POST" return httpCall(url,options,data) end
  function http.delete(url,options) options=options or {}; options.method="DELETE" return httpCall(url,options) end
  Util.defvar("http",http)
  Util.defvar("QA",quickApp)

  local equations = {}
  function equations.linear(t, b, c, d) return c * t / d + b; end
  function equations.inQuad(t, b, c, d) t = t / d; return c * math.pow(t, 2) + b; end
  function equations.inOutQuad(t, b, c, d) t = t / d * 2; return t < 1 and c / 2 * math.pow(t, 2) + b or -c / 2 * ((t - 1) * (t - 3) - 1) + b end
  function equations.outInExpo(t, b, c, d) return t < d / 2 and equations.outExpo(t * 2, b, c / 2, d) or equations.inExpo((t * 2) - d, b + c / 2, c / 2, d) end
  function equations.inExpo(t, b, c, d) return t == 0 and b or c * math.pow(2, 10 * (t / d - 1)) + b - c * 0.001 end
  function equations.outExpo(t, b, c, d) return t == d and  b + c or c * 1.001 * (-math.pow(2, -10 * t / d) + 1) + b end
  function equations.inOutExpo(t, b, c, d)
    if t == 0 then return b elseif t == d then return b + c end
    t = t / d * 2
    if t < 1 then return c / 2 * math.pow(2, 10 * (t - 1)) + b - c * 0.0005 else t = t - 1; return c / 2 * 1.0005 * (-math.pow(2, -10 * t) + 2) + b end
  end

  function Util.dimLight(id,sec,dir,step,curve,start,stop)
    _assert(tonumber(sec), "Bad dim args for deviceID:%s",id)
    local f = curve and equations[curve] or equations['linear']
    dir,step = dir == 'down' and -1 or 1, step or 1
    start,stop = start or 0,stop or 99
    self:post({type='%dimLight',id=id,sec=sec,dir=dir,fun=f,t=dir == 1 and 0 or sec,start=start,stop=stop,step=step,_sh=true})
  end

  self:event({type='%dimLight'},function(env)
      local e = env.event
      local ev,currV = e.v or -1,tonumber(fibaro.getValue(e.id,"value"))
      if not currV then
        self:warningf("Device %d can't be dimmed. Type of value is %s",e.id,type(fibaro.getValue(e.id,"value")))
      end
      if e.v and math.abs(currV - e.v) > 2 then return end -- Someone changed the lightning, stop dimming
      e.v = math.floor(e.fun(e.t,e.start,(e.stop-e.start),e.sec)+0.5)
      if ev ~= e.v then fibaro.call(e.id,"setValue",e.v) end
      e.t=e.t+e.dir*e.step
      if 0 <= e.t and  e.t <= e.sec then self:post(e,os.time()+e.step) end
    end)

  self:event({type='alarm', property='homeArmed'},
    function(env) self:post({type='alarm',property='armed',id=0, value=env.event.value}) 
    end)
  self:event({type='alarm', property='homeBreached'},
    function(env) self:post({type='alarm',property='breached',id=0, value=env.event.value}) 
    end)

  local function getFibObj(path,p,k,v)
    local oo = api.get(path) or {}
    if p then oo = oo[p] end
    for _,o in ipairs(oo or {}) do
      if o[k]==v then return o end
    end
  end

  Util.defvar("LOC", function(name) return getFibObj("/panels/location",nil,"name",name) end)
  Util.defvar("USER", function(name) return getFibObj("/users",nil,"name",name) end)
  Util.defvar("PHONE", function(name) return getFibObj("/iosDevices",nil,"name",name) end)
  Util.defvar("PART", function(name) return getFibObj("/alarms/v1/partitions",nil,"name",name) end)    
  Util.defvar("PROF", function(name) return getFibObj("/profiles","profiles","name",name) end)
  Util.defvar("CLIM", function(name) return getFibObj("/panels/climate",nil,"name",name) end)
  Util.defvar("SPRINK", function(name) return getFibObj("/panels/sprinklers",nil,"name",name) end)

end

----------------- EventScript support -------------------------
Module.eventScript = { name="ER EventScript", version="0.7"}
function Module.eventScript.init()
  if Module.eventScript.inited then return Module.eventScript.inited end
  Module.eventScript.inited = true 

  local ScriptParser,ScriptCompiler,ScriptEngine,gStatements

  local function makeEventScriptParser()
    local source, tokens, cursor
    local mkStack,mkStream,toTime,map,mapk,gensym=Util.mkStack,Util.mkStream,fibaro.toTime,table.map,table.mapk,fibaro.utils.gensym
    local patterns,self = {},{}
    local opers = {['%neg']={14,1},['t/']={14,1,'%today'},['n/']={14,1,'%nexttime'},['+/']={14,1,'%plustime'},['$']={14,1,'%vglob'},
      ['$$']={14,1,'%vquick'},
      ['.']={12.9,2},[':']= {13,2,'%prop'},['..']={9,2,'%betw'},['...']={9,2,'%betwo'},['@']={9,1,'%daily'},['jmp']={9,1},['::']={9,1},--['return']={-0.5,1},
      ['@@']={9,1,'%interv'},['+']={11,2},['++']={10,2},['===']={9,2},
      ['-']={11,2},['*']={12,2},['/']={12,2},['%']={12,2},['==']={6,2},['<=']={6,2},
      ['>=']={6,2},['~=']={6,2},
      ['>']={6,2},['<']={6,2},['&']={5,2,'%and'},['|']={4,2,'%or'},['!']={5.1,1,'%not'},['=']={0,2},['+=']={0,2},['-=']={0,2},
      ['*=']={0,2},[';']={-1,2,'%progn'},[';;']={-1,2,'%progn'},
    }
    local nopers = {['jmp']=true,}--['return']=true}
    local reserved={
      ['sunset']={{'sunset'}},['sunrise']={{'sunrise'}},['midnight']={{'midnight'}},['dusk']={{'dusk'}},['dawn']={{'dawn'}},
      ['now']={{'now'}},['wnum']={{'wnum'}},['env']={{'env'}},
      ['true']={true},['false']={false},['{}']={{'quote',{}}},['nil']={{'%quote',nil}},
    }
    local function apply(t,st) return st.push(st.popn(opers[t.value][2],{t.value})) end
    local _samePrio = {['.']=true,[':']=true}
    local function lessp(t1,t2) 
      local v1,v2 = t1.value,t2.value
      if v1==':' and v2=='.' then return true 
      elseif v1=='=' then v1='/' end
      return v1==v2 and _samePrio[v1] or opers[v1][1] < opers[v2][1] 
    end
    local function isInstr(i,t) return type(i)=='table' and i[1]==t end

    local function tablefy(t)
      local res={}
      for k,e in pairs(t) do if isInstr(e,'=') then res[e[2][2]]=e[3] else res[k]=e end end
      return res
    end

    local pExpr,gExpr,gStatement={}
    pExpr['lpar']=function(inp,st,ops,_,pt)
      if pt.value:match("^[%]%)%da-zA-Z]") then 
        while not ops.isEmpty() and opers[ops.peek().value][1] >= 12.9 do apply(ops.pop(),st) end
        local fun,args = st.pop(),self.gArgs(inp,')')
        if isInstr(fun,':') then st.push({'%calls',{'%aref',fun[2],fun[3]},fun[2],table.unpack(args)})
        elseif isInstr(fun,'%var') then st.push({fun[2],table.unpack(args)})
        elseif type(fun)=='string' then st.push({fun,table.unpack(args)})
        else st.push({'%calls',fun,table.unpack(args)}) end
      else
        st.push(gExpr(inp,{[')']=true})) inp.next()
      end
    end
    pExpr['lbra']=function(inp,st,ops,_,_) 
      while not ops.isEmpty() and opers[ops.peek().value][1] >= 12.9 do apply(ops.pop(),st) end
      st.push({'%aref',st.pop(),gExpr(inp,{[']']=true})}) inp.next() 
    end
    pExpr['lor']=function(inp,st,_,_,_) 
      local e = gExpr(inp,{['>>']=true}); inp.next()
      local body,el = gStatements(inp,{[';;']=true,['||']=true})
      if inp.peek().value == '||' then el = gExpr(inp,{[';;']=true}) end
      st.push({'if',e,body,el})
    end
    pExpr['lcur']=function(inp,st,_,_,_) st.push({'%table',tablefy(self.gArgs(inp,'}'))}) end
    pExpr['ev']=function(inp,st,_,t,_) local v = {}
      if inp.peek().value == '{' then inp.next() v = tablefy(self.gArgs(inp,'}')) end
      v.type = t.value:sub(2); st.push({'%table',v})
    end
    pExpr['num']=function(_,st,_,t,_) st.push(t.value) end
    pExpr['str']=function(_,st,_,t,_) st.push(t.value) end
    pExpr['nam']=function(_,st,_,t,pt) 
      if reserved[t.value] then st.push(reserved[t.value][1]) 
      elseif pt.value == '.' or pt.value == ':' then st.push(t.value) 
      else st.push({'%var',t.value,'script'}) end -- default to script vars
    end
    pExpr['op']=function(_,st,ops,t,pt)
      if t.value == '-' and not(pt.type == 'name' or pt.type == 'number' or pt.value == '(') then t.value='%neg' end
      while ops.peek() and lessp(t,ops.peek()) do apply(ops.pop(),st) end
      ops.push(t)
    end

    function gExpr(inp,stop)
      local st,ops,t,pt=mkStack(),mkStack(),{value='<START>'}
      while true do
        t,pt = inp.peek(),t
        if t.type=='eof' or stop and stop[t.value] then break end
        t = inp.next()
        pExpr[t.sw](inp,st,ops,t,pt)
      end
      while not ops.isEmpty() do apply(ops.pop(),st) end
      --st.dump()
      local r = st.pop()
      if not st.isEmpty() then
        error("Bad expression "..json.encode(st.pop()))
      end
      return r
    end

    function self.gArgs(inp,stop)
      local res,i = {},1
      while inp.peek().value ~= stop do _assert(inp.peek().type~='eof',"Missing ')'"); res[i] = gExpr(inp,{[stop]=true,[',']=true}); i=i+1; if inp.peek().value == ',' then inp.next() end end
      inp.next() return res
    end

    local function token(pattern, createFn)
      table.insert(patterns, function ()
          local _, len, res, group = string.find(source, "^(" .. pattern .. ")")
          if len then
            if createFn then
              local tokenv = createFn(group or res)
              tokenv.from, tokenv.to = cursor, cursor+len
              table.insert(tokens, tokenv)
            end
            source = string.sub(source, len+1)
            cursor = cursor + len
            return true
          end
        end)
    end

    local function toTimeDate(str)
      local y,m,d,h,min,s=str:match("(%d?%d?%d?%d?)/?(%d+)/(%d+)/(%d%d):(%d%d):?(%d?%d?)")
      local t = os.date("*t")
      return os.time{year=y~="" and y or t.year,month=m,day=d,hour=h,min=min,sec=s~="" and s or 0}
    end

    local SW={['(']='lpar',['{']='lcur',['[']='lbra',['||']='lor'}
    token("[%s%c]+")
--2019/3/30/20:30
    token("%d?%d?%d?%d?/?%d+/%d+/%d%d:%d%d:?%d?%d?",function (t) return {type="number", sw='num', value=toTimeDate(t)} end)
    token("%d%d:%d%d:?%d?%d?",function (t) return {type="number", sw='num', value=toTime(t)} end)
    token("%d+:%d+",function (_) error('Bad time constant') end)
    token("[t+n][/]", function (op) return {type="operator", sw='op', value=op} end)
    token("#[A-Za-z_][%w_%-]*", function (w) return {type="event", sw='ev', value=w} end)
--token("[A-Za-z_][%w_]*", function (w) return {type=nopers[w] and 'operator' or "name", sw=nopers[w] and 'op' or 'nam', value=w} end)
    token("[_a-zA-Z\xC3\xA5\xA4\xB6\x85\x84\x96][_0-9a-zA-Z\xC3\xA5\xA4\xB6\x85\x84\x96]*", function (w) return {type=nopers[w] and 'operator' or "name", sw=nopers[w] and 'op' or 'nam', value=w} end)
    token("%d+%.%d+", function (d) return {type="number", sw='num', value=tonumber(d)} end)
    token("%d+", function (d) return {type="number", sw='num', value=tonumber(d)} end)
    token('"([^"]*)"', function (s) return {type="string", sw='str', value=s} end)
    token("'([^']*)'", function (s) return {type="string", sw='str', value=s} end)
    token("%-%-.-\n")
    token("%-%-.*")  
    token("===",function (op) return {type="operator", sw=SW[op] or 'op', value=op} end)    
    token("%.%.%.",function (op) return {type="operator", sw=SW[op] or 'op', value=op} end)
    token("[%$%$]", function (op) return {type="operator", sw=SW[op] or 'op', value=op} end)
    token("[@%$=<>!+%.%-*&|/%^~;:][%+@=<>&|;:%.]?", function (op) return {type="operator", sw=SW[op] or 'op', value=op} end)
    token("[{}%(%),%[%]#%%]", function (op) return {type="operator", sw=SW[op] or 'op', value=op} end)


    local function dispatch() for _,m in ipairs(patterns) do if m() then return true end end end

    local function tokenize(src)
      source, tokens, cursor = src, {}, 0
      while #source>0 and dispatch() do end
      if #source > 0 then print("tokenizer failed at " .. source) end
      return tokens
    end

    local postP={}
    postP['%progn'] = function(e) local r={'%progn'}
      map(function(p) if isInstr(p,'%progn') then for i=2,#p do r[#r+1] = p[i] end else r[#r+1]=p end end,e,2)
      return r
    end
    postP['%vglob'] = function(e) return {'%var',e[2][2],'glob'} end
    postP['%vquick'] = function(e) return {'%var',e[2][2],'quick'} end
    postP['='] = function(e) 
      local lv,rv = e[2],e[3]
      if type(lv) == 'table' and ({['%var']=true,['%prop']=true,['%aref']=true})[lv[1]] then
        return {'%set',lv[1]:sub(1,1)~='%' and '%'..lv[1] or lv[1],lv[2], lv[3] or true, rv}
      else error("Illegal assignment") end
    end
    postP['%betwo'] = function(e) 
      local t = fibaro.utils.gensym("TODAY")
      return {'%and',{'%betw', e[2],e[3]},{'%and',{'~=',{'%var',t,'script'},{'%var','dayname','script'}},{'%set','%var',t,'script',{'%var','dayname','script'}}}}
    end 
    postP['if'] = function(e) local c = {'%and',e[2],{'%always',e[3]}} return self.postParse(#e==3 and c or {'%or',c,e[4]}) end
    postP['=>'] = function(e) return {'%rule',{'%quote',e[2]},{'%quote',e[3]}} end
    postP['.'] = function(e) return {'%aref',e[2],e[3]} end
    postP['::'] = function(e) return {'%addr',e[2][2]} end
    postP['%jmp'] = function(e) return {'%jmp',e[2][2]} end
-- preC['return'] = function(e) return {'return',e[2]} end
    postP['++'] = function(e) return {'%concat',e[2],e[3]} end
    postP['==='] = function(e) return {'%match',e[2],e[3]} end
    postP['%neg'] = function(e) return tonumber(e[2]) and -e[2] or e end
    postP['+='] = function(e) return {'%inc',e[2],e[3],'+'} end
    postP['-='] = function(e) return {'%inc',e[2],e[3],'-'} end
    postP['*='] = function(e) return {'%inc',e[2],e[3],'*'} end
    postP['+'] = function(e) return tonumber(e[2]) and tonumber(e[3]) and tonumber(e[2])+tonumber(e[3]) or e end
    postP['-'] = function(e) return tonumber(e[2]) and tonumber(e[3]) and tonumber(e[2])-tonumber(e[3]) or e end
    postP['*'] = function(e) return tonumber(e[2]) and tonumber(e[3]) and tonumber(e[2])*tonumber(e[3]) or e end
    postP['/'] = function(e) return tonumber(e[2]) and tonumber(e[3]) and tonumber(e[2])/tonumber(e[3]) or e end
    postP['%'] = function(e) return tonumber(e[2]) and tonumber(e[3]) and tonumber(e[2])%tonumber(e[3]) or e end

    function self.postParse(e0)
      local function traverse(e)
        if type(e)~='table' or e[1]=='quote' then return e end
        if opers[e[1]] then 
          e[1]=opers[e[1]][3] or e[1]
        end
        local pc = mapk(traverse,e); return postP[pc[1]] and postP[pc[1]](pc) or pc
      end
      return traverse(e0)
    end

    local gElse
    local function matchv(inp,t,v) local t0=inp.next(); _assert(t0.value==t,"Expected '%s' in %s",t,v); return t0 end
    local function matcht(inp,t,v) local t0=inp.next(); _assert(t0.type==t,"Expected %s",v); return t0 end

    local function mkVar(n) return {'%var',n and n or gensym("V"),'script'} end
    local function mkSet(v,e) return {'%set',v[1],v[2],v[3],e} end        
    function gStatement(inp,stop)
      local t,vars,exprs = inp.peek(),{},{}
      if t.value=='local' then inp.next()
        vars[1] = matcht(inp,'name',"variable in 'local'").value
        while inp.peek().value==',' do inp.next(); vars[#vars+1]= matcht(inp,'name',"variable in 'local'").value end
        if inp.peek().value == '=' then
          inp.next()
          exprs[1] = {gExpr(inp,{[',']=true,[';']=true})}
          while inp.peek().value==',' do inp.next(); exprs[#exprs+1]= {gExpr(inp,{[',']=true,[';']=true})} end
        end
        return {'%local',vars,exprs}
      elseif t.value == 'while' then inp.next()
        local test = gExpr(inp,{['do']=true}); matchv(inp,'do',"While loop")
        local body = gStatements(inp,{['end']=true}); matchv(inp,'end',"While loop")
        return {'%frame',{'%while',test,body}}
      elseif t.value == 'repeat' then inp.next()
        local body = gStatements(inp,{['until']=true}); matchv(inp,'until',"Repeat loop")
        local test = gExpr(inp,stop)
        return {'%frame',{'%repeat',body,test}}
      elseif t.value == 'begin' then inp.next()
        local body = gStatements(inp,{['end']=true}); matchv(inp,'end',"Begin block")
        return {'%frame',body} 
      elseif t.value == 'for' then inp.next()
        local var = matcht(inp,'name').value; 
        if inp.peek().value==',' then -- for a,b in f(x) do ...  end
          matchv(inp,','); --local l,a,b,c,i; c=pack(f(x)); i=c[1]; l=c[2]; c=pack(i(l,c[3])); while c[1] do a=c[1]; b=c[2]; ... ; c=pack(i(l,a)) end
          local var2 = matcht(inp,'name').value; 
          matchv(inp,'in',"For loop"); 
          local expr = gExpr(inp,{['do']=true}); matchv(inp,'do',"For loop")
          local body = gStatements(inp,{['end']=true}); matchv(inp,'end',"For loop")
          local v1,v2,i,l = mkVar(var),mkVar(var2),mkVar(),mkVar()
          return {'%frame',{'%progn',{'%local',{var,var2,l[2],i[2]},{}},
              {'setList',{i,l,v1},{'pack',expr}},{'setList',{v1,v2},{'pack',{'%calls',i,l,v1}}},
              {'%while',v1,{'%progn',body,{'setList',{v1,v2},{'pack',{'%calls',i,l,v1}}}}}}}
        else -- for for a = x,y,z  do ... end
          matchv(inp,'=') -- local a,e,s,si=x,y,z; si=sign(s); e*=si while a*si<=e do ... a+=s end
          local inits = {}
          inits[1] = {gExpr(inp,{[',']=true,['do']=true})}
          while inp.peek().value==',' do inp.next(); inits[#inits+1]= {gExpr(inp,{[',']=true,['do']=true})} end
          matchv(inp,'do',"For loop")
          local body = gStatements(inp,{['end']=true}); matchv(inp,'end',"For loop")
          local v,s,e,step = mkVar(var),mkVar(),mkVar(),mkVar()
          if #inits<3 then inits[#inits+1]={1} end
          local locals = {'%local',{var,e[2],step[2],s[2]},inits}
          return {'%frame',{'%progn',locals,mkSet(s,{'sign',step}),{'*=',e,s},{'%while',{'<=',{'*',v,s},e},{'%progn',body,{'+=',v,step}}}}}
        end
      elseif t.value == 'if' then inp.next()
        local test = gExpr(inp,{['then']=true}); matchv(inp,'then',"If statement")
        local body = gStatements(inp,{['end']=true,['else']=true,['elseif']=true})
        return {'if',test,{'%frame',body},gElse(inp)}
      else return gExpr(inp,stop) end 
    end

    function gElse(inp)
      if inp.peek().value=='end' then inp.next(); return nil end
      if inp.peek().value=='else' then inp.next()
        local r = gStatements(inp,{['end']=true}); matchv(inp,'end',"If statement"); return {'%frame',r}
      end
      if inp.peek().value=='elseif' then inp.next(); 
        local test = gExpr(inp,{['then']=true}); matchv(inp,'then',"If statement")
        local body = gStatements(inp,{['end']=true,['else']=true,['elseif']=true})  
        return {'if',test,{'%frame',body},gElse(inp)}
      end
      error("Bad formed if-then-else stmt")
    end

    function gStatements(inp,stop)
      local progn = {'%progn'}; stop=stop or {}; stop[';']=true; progn[2] = gStatement(inp,stop)
      while inp.peek().value == ';' do
        inp.next(); progn[#progn+1] = gStatement(inp,stop)
      end
      return #progn > 2 and progn or progn[2]
    end

    local statement={['while']=true,['repeat']=true,['if']=true,['local']=true,['begin']=true,['for']=true}
    local function gRule(inp)
      if statement[inp.peek().value] then return gStatements(inp) end
      local e = gExpr(inp,{['=>']=true,[';']=true})
      if inp.peek().value=='=>' then inp.next()
        return {'=>',e,gStatements(inp)}
      elseif inp.peek().value==';' then inp.next()
        local s = gStatements(inp)
        return {'%progn',e,s}
      else return e end
    end

    function self.parse(str)
      local tokensa = mkStream(tokenize(str))
      --for i,v in ipairs(tokens.stream) do print(v.type, v.value, v.from, v.to) end
      local stat,res = pcall(function() return self.postParse(gRule(tokensa)) end)
      if not stat then local t=tokensa.last() error(string.format("Parser error char %s ('%s') in expression '%s' (%s)",t.from+1,str:sub(t.from+1,t.to),str,res)) end
      return res
    end

    return self
  end

---------- Event Script Compiler --------------------------------------
  local function makeEventScriptCompiler(parser)
    local self,comp,gensym={ parser=parser },{},fibaro.utils.gensym
    local function mkOp(o) return o end
    local POP = {mkOp('%pop'),0}

    local function compT(e,ops)
      if type(e) == 'table' then
        local ef = e[1]
        if comp[ef] then comp[ef](e,ops)
        else for i=2,#e do compT(e[i],ops) end ops[#ops+1] = {mkOp(e[1]),#e-1} end -- built-in fun
      else 
        ops[#ops+1]={mkOp('%push'),0,e} -- constants etc
      end
    end

    comp['%quote'] = function(e,ops) ops[#ops+1] = {mkOp('%push'),0,e[2]} end
    comp['%var'] = function(e,ops) ops[#ops+1] = {mkOp('%var'),0,e[2],e[3]} end
    comp['%addr'] = function(e,ops) ops[#ops+1] = {mkOp('%addr'),0,e[2]} end
    comp['%jmp'] = function(e,ops) ops[#ops+1] = {mkOp('%jmp'),0,e[2]} end
    comp['%frame'] = function(e,ops) ops[#ops+1] = {mkOp('%frame'),0} compT(e[2],ops) ops[#ops+1] = {mkOp('%unframe'),0} end  
    comp['%eventmatch'] = function(e,ops) ops[#ops+1] = {mkOp('%eventmatch'),0,e[2],e[3]} end
    comp['setList'] = function(e,ops) compT(e[3],ops); ops[#ops+1]={mkOp('%setlist'),1,e[2]} end
    comp['%set'] = function(e,ops)
      if e[2]=='%var' then
        if type(e[5])~='table' then ops[#ops+1] = {mkOp('%setvar'),0,e[3],e[4],e[5]} 
        else compT(e[5],ops); ops[#ops+1] = {mkOp('%setvar'),1,e[3],e[4]} end
      else
        local args,n = {},1;
        if type(e[4])~='table' then args[2]={e[4]} else args[2]=false compT(e[4],ops) n=n+1 end
        if type(e[5])~='table' then args[1]={e[5]} else args[1]=false compT(e[5],ops) n=n+1 end
        compT(e[3],ops)
        ops[#ops+1] = {mkOp('%set'..e[2]:sub(2)),n,table.unpack(args)} 
      end
    end
    comp['%aref'] = function(e,ops)
      compT(e[2],ops) 
      if type(e[3])~='table' then ops[#ops+1] = {mkOp('%aref'),1,e[3]} 
      else compT(e[3],ops); ops[#ops+1] = {mkOp('%aref'),2} end
    end
    comp['%prop'] = function(e,ops)
      _assert(type(e[3])=='string',"non constant property '%s'",function() return json.encode(e[3]) end)
      compT(e[2],ops); ops[#ops+1] = {mkOp('%prop'),1,e[3]} 
    end
    comp['%table'] = function(e,ops) local keys={}
      for key,val in pairs(e[2]) do keys[#keys+1] = key; compT(val,ops) end
      ops[#ops+1]={mkOp('%table'),#keys,keys}
    end
    comp['%and'] = function(e,ops) 
      compT(e[2],ops)
      local o1,z = {mkOp('%ifnskip'),0,0}
      ops[#ops+1] = o1 -- true skip
      z = #ops; ops[#ops+1]= POP; compT(e[3],ops); o1[3] = #ops-z+1
    end
    comp['%or'] = function(e,ops)  
      compT(e[2],ops)
      local o1,z = {mkOp('%ifskip'),0,0}
      ops[#ops+1] = o1 -- true skip
      z = #ops; ops[#ops+1]= POP; compT(e[3],ops); o1[3] = #ops-z+1;
    end
    comp['%inc'] = function(e,ops) 
      if tonumber(e[3]) then ops[#ops+1] = {mkOp('%inc'..e[4]),0,e[2][2],e[2][3],e[3]}
      else compT(e[3],ops) ops[#ops+1] = {mkOp('%inc'..e[4]),1,e[2][2],e[2][3]} end 
    end
    comp['%progn'] = function(e,ops)
      if #e == 2 then compT(e[2],ops) 
      elseif #e > 2 then for i=2,#e-1 do compT(e[i],ops); ops[#ops+1]=POP end compT(e[#e],ops) end
    end
    comp['%local'] = function(e,ops)
      for _,e1 in ipairs(e[3]) do compT(e1[1],ops) end
      ops[#ops+1]={mkOp('%local'),#e[3],e[2]}
    end
    comp['%while'] = function(e,ops) -- lbl1, test, infskip lbl2, body, jmp lbl1, lbl2
      local test,body,lbl1=e[2],e[3],gensym('LBL1')
      local jmp={mkOp('%ifnskip'),0,nil,true}
      ops[#ops+1] = {'%addr',0,lbl1}; ops[#ops+1] = POP
      compT(test,ops); ops[#ops+1]=jmp; 
      local cp=#ops
      compT(body,ops); ops[#ops+1]=POP; ops[#ops+1]={mkOp('%jmp'),0,lbl1}
      jmp[3]=#ops+1-cp
    end
    comp['%repeat'] = function(e,ops) -- -- lbl1, body, test, infskip lbl1
      local body,test,z=e[2],e[3],#ops
      compT(body,ops); ops[#ops+1]=POP; compT(test,ops)
      ops[#ops+1] = {mkOp('%ifnskip'),0,z-#ops,true}
    end

    function self.compile(src,log) 
      local code,res=type(src)=='string' and self.parser.parse(src) or src,{}
      if log and log.code then print(json.encode(code)) end
      compT(code,res) 
      if log and log.code then if ScriptEngine then  ScriptEngine.dump(res) end end
      return res 
    end
    function self.compile2(code) local res={}; compT(code,res); return res end
    return self
  end

---------- Event Script RunTime --------------------------------------
  local function makeEventScriptRuntime()
    local self,instr={},{}
    local coroutine = Util.coroutine
    local function safeEncode(e) local stat,res = pcall(function() return tojson(e) end) return stat and res or tostring(e) end
    local toTime,midnight,map,mkStack,copy,coerce,isEvent=fibaro.toTime,fibaro.midnight,table.map,Util.mkStack,table.copy,fibaro.EM.coerce,fibaro.EM.isEvent
    local _vars,triggerVar = Util._vars,Util.triggerVar

    local oldFormat
    oldFormat,string.format = string.format,function(fmt,...)
      local r={}; for _,e in ipairs({...}) do r[#r+1]=type(e)=='table' and tostring(e) or e end
      return oldFormat(fmt,unpack(r))
    end

    local function addRuleTimer(rule,ref) rule.timers[ref]=true end
    local function clearRuleTimer(rule,ref) rule.timers[ref]=nil end

    local function userLogFunction(rule,fmt,...)
      local args,t1,t0,str,c1 = {...},rule._tag or __TAG,__TAG
      str = #args==0 and tostring(fmt) or string.format(fmt,...)
      str = str:gsub("(#T:)(.-)(#)",function(_,t) t1=t return "" end)
      str = str:gsub("(#C:)(.-)(#)",function(_,c) c1=c return "" end)
      if c1 then str=string.format("<font color=%s>%s</font>",c1,str) end
      __TAG = t1; quickApp:trace(str); __TAG = t0
      return str
    end

    local function getVarRec(var,locs) return locs[var] or locs._next and getVarRec(var,locs._next) end
    local function getVar(var,env) local v = getVarRec(var,env.locals); env._lastR = var
      if v then return v[1]
      elseif _vars[var] then return _vars[var][1]
      elseif (_ENV or _G)[var]~=nil then return (_ENV or _G)[var] end
    end
    local function setVar(var,val,env) local v = getVarRec(var,env.locals)
      if v then v[1] = val
      else
        local oldVal 
        if _vars[var] then oldVal=_vars[var][1]; _vars[var][1] = val else _vars[var]={val} end
        if triggerVar(var) and oldVal ~= val then quickApp:post({type='variable', name=var, value=val}) end
        --elseif (_ENV or _G)[var] then return (_ENV or _G)[var] end -- allow for setting Lua globals
      end
      return val 
    end

    -- Primitives
    instr['%pop'] = function(s) s.pop() end
    instr['%push'] = function(s,_,_,i) s.push(i[3]) end
    instr['%ifnskip'] = function(s,_,e,i) if not s.peek() then e.cp=e.cp+i[3]-1; end if i[4] then s.pop() end end
    instr['%ifskip'] = function(s,_,e,i) if s.peek() then e.cp=e.cp+i[3]-1; end if i[4] then s.pop() end end
    instr['%addr'] = function(s,_,_,i) s.push(i[3]) end
    instr['%frame'] = function(_,_,e,_)  e.locals = {_next=e.locals} end
    instr['%unframe'] = function(_,_,e,_)  e.locals = e.locals._next end
    instr['%jmp'] = function(_,_,e,i) local addr,c,p = i[3],e.code,i[4]
      if p then  e.cp=p-1 return end  -- First time we search for the label and cache the position
      for k=1,#c do if c[k][1]=='%addr' and c[k][3]==addr then i[4]=k e.cp=k-1 return end end 
      error({"jump to bad address:"..addr}) 
    end
    instr['%table'] = function(s,n,_,i) local k,t = i[3],{} for j=n,1,-1 do t[k[j]] = s.pop() end s.push(t) end
    local function getArg(s,e) if e then return e[1] else return s.pop() end end
    instr['%aref'] = function(s,n,e,i) local k,tab 
      if n==1 then k,tab=i[3],s.pop() else k,tab=s.pop(),s.pop() end
      local tt = type(tab)
      _assert(tt=='table' or tt=='userdata',"attempting to index non table with key:'%s'",k); e._lastR = k
      s.push(tab[k])
    end
    instr['%setaref'] = function(s,_,_,i) local r,v,k = s.pop(),getArg(s,i[3]),getArg(s,i[4])
      _assertf(type(r)=='table',"trying to set non-table value '%s'",function() return json.encode(r) end)
      r[k]= v; s.push(v) 
    end
    local _marshalBool={['true']=true,['True']=true,['TRUE']=true,['false']=false,['False']=false,['FALSE']=false}

    local function marshallFrom(v) 
      if not _MARSHALL then return v elseif v==nil then return v end
      local fc = v:sub(1,1)
      if fc == '[' or fc == '{' then local s,t = pcall(json.decode,v); if s then return t end end
      if tonumber(v) then return tonumber(v)
      elseif _marshalBool[v ]~=nil then return _marshalBool[v ] end
      local s,t = pcall(toTime,v); return s and t or v 
    end
    local function marshallTo(v) 
      if not _MARSHALL then return tostring(v) end
      if type(v)=='table' then return safeEncode(v) else return tostring(v) end
    end
    local getVarFs = { 
      script=getVar, 
      glob=function(n,_) return marshallFrom(fibaro.getGlobalVariable(n)) end,
      quick=function(n,_) 
        local v = quickApp:getVariable(n)
        if v == "" then v = nil end
        return marshallFrom(v) 
      end
    }
    local setVarFs = { 
      script=setVar, 
      glob=function(n,v,_) fibaro.setGlobalVariable(n,marshallTo(v)) return v end,
      quick=function(n,v,_) quickApp:setVariable(n,marshallTo(v)) return v end 
    }
    instr['%var'] = function(s,_,e,i) s.push(getVarFs[i[4]](i[3],e)) end
    instr['%setvar'] = function(s,n,e,i) if n==1 then setVarFs[i[4]](i[3],s.peek(),e) else s.push(setVarFs[i[4]](i[3],i[5],e)) end end
    instr['%local'] = function(s,n,e,i) local vn,ve = i[3],s.lift(n); e.locals = e.locals or {}
      local j,x=1; for _,v in ipairs(vn) do x=ve[j]; e.locals[v]={ve[j]}; j=j+1 end
      s.push(x) 
    end
    instr['%setlist'] = function(s,_,e,i) 
      local vars,arg,r = i[3],s.pop() 
      for j,v in ipairs(vars) do r=setVarFs[v[3]](v[2],arg[j],e) end 
      s.push(r) 
    end
    instr['%concat'] = function(s,_,_,_) local s2,s1=s.pop(),s.pop() s.push(tostring(s1)..tostring(s2)) end 
    instr['%match'] = function(s,_,_,_) local m,str=s.pop(),s.pop() s.push(tostring(str):match(tostring(m))) end
    instr['trace'] = function(s,_,_) _traceInstrs=s.peek() end
    instr['pack'] = function(s,_,_) local res=s.get(1); s.pop(); s.push(res) end
    instr['env'] = function(s,_,e) s.push(e) end
    local function resume(co,e)
      local res = {coroutine.resume(co)}
      if res[1]==true then
        if coroutine.status(co)=='dead' then e.log.cont(select(2,table.unpack(res))) end
      elseif isError(res[1]) then error(res[1].err..", "..(res[1].msg or ""))
      else error(res[2] or "coroutine crashed") end
    end
    local function handleCall(s,e,fun,args)
      local res = table.pack(fun(table.unpack(args)))
      if type(res[1])=='table' and res[1]['<cont>'] then
        local co = e.co
        setTimeout(function() res[1]['<cont>'](function(...) local r=table.pack(...); s.push(r[1]); s.set(1,r); resume(co,e) end) end,0)
        return 'suspended',{}
      else s.push(res[1]) s.set(1,res) end
    end
    instr['%call'] = function(s,n,e,i) local fun = getVar(i[1] ,e); _assert(type(fun)=='function',"No such function:%s",i[1] or "nil")
      return handleCall(s,e,fun,s.lift(n))
    end
    instr['%calls'] = function(s,n,e,_) local args,fun = s.lift(n-1),s.pop(); _assert(type(fun)=='function',"No such function:%s",fun or "nil")
      return handleCall(s,e,fun,args)
    end
    instr['yield'] = function(s,n,_,_) local r = s.lift(n); s.push(nil); return 'suspended',r end
    instr['return'] = function(s,n,_,_) return 'dead',s.lift(n) end
    instr['wait'] = function(s,_,e,_) local t,co,r=s.pop(),e.co; t=t < os.time() and t or t-os.time(); s.push(t);
      r = setTimeout(function()
          clearRuleTimer(e.rule,r) 
          local stat,res = pcall(resume,co,e)
          if not stat then
            quickApp:errorf("'%s' - %s",e.src or "",trimError(res) or "") 
          end
        end,t*1000);
      addRuleTimer(e.rule,r) 
      return 'suspended',{}
    end
    instr['kill'] = function(s,_,e,_) local ep=s.pop() or e.rule
      if ep and ep.timers then 
        for t,_ in pairs(ep.timers) do clearTimeout(t) end
        ep.timers = {}
      end 
    end
    instr['%not'] = function(s,_) s.push(not s.pop()) end
    instr['%neg'] = function(s,_) s.push(-tonumber(s.pop())) end
    instr['+'] = function(s,_) s.push(s.pop()+s.pop()) end
    instr['-'] = function(s,_) s.push(-s.pop()+s.pop()) end
    instr['*'] = function(s,_) s.push(s.pop()*s.pop()) end
    instr['/'] = function(s,_) local y,x=s.pop(),s.pop() s.push(x/y) end
    instr['%'] = function(s,_) local a,b=s.pop(),s.pop(); s.push(b % a) end
    instr['%inc+'] = function(s,n,e,i) local var,t,val=i[3],i[4] if n>0 then val=s.pop() else val=i[5] end 
    s.push(setVarFs[t](var,getVarFs[t](var,e)+val,e)) end
    instr['%inc-'] = function(s,n,e,i) local var,t,val=i[3],i[4]; if n>0 then val=s.pop() else val=i[5] end 
    s.push(setVarFs[t](var,getVarFs[t](var,e)-val,e)) end
    instr['%inc*'] = function(s,n,e,i) local var,t,val=i[3],i[4]; if n>0 then val=s.pop() else val=i[5] end
    s.push(setVarFs[t](var,getVarFs[t](var,e)*val,e)) end
    instr['>'] = function(s,_) local y,x=coerce(s.pop(),s.pop()) s.push(x>y) end
    instr['<'] = function(s,_) local y,x=coerce(s.pop(),s.pop()) s.push(x<y) end
    instr['>='] = function(s,_) local y,x=coerce(s.pop(),s.pop()) s.push(x>=y) end
    instr['<='] = function(s,_) local y,x=coerce(s.pop(),s.pop()) s.push(x<=y) end
    instr['~='] = function(s,_) local y,x=coerce(s.pop(),s.pop()) s.push(x~=y) end
    instr['=='] = function(s,_) local y,x=coerce(s.pop(),s.pop()) s.push(x==y) end

-- ER funs
    local getFuns,setFuns
    local _getFun = function(id,prop) return fibaro.get(id,prop) end

    do -- get/set functions
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
      local get = _getFun
      local function on(id,prop) return BN(fibaro.get(id,prop)) > 0 end
      local function off(id,prop) return BN(fibaro.get(id,prop)) == 0 end
      local function last(id,prop) local _,t=fibaro.get(id,prop); return t and os.time()-t or 0 end
      local function cce(id,_,e) 
        e=e.event; return e.type=='device' and e.property=='centralSceneEvent'and e.id==id and e.value or {} 
      end
      local function ace(id,_,e) 
        e=e.event; return e.type=='device' and e.property=='accessControlEvent' and e.id==id and e.value or {} 
      end
      local function sae(id,_,e) 
        e=e.event; return e.type=='device' and e.property=='sceneActivationEvent' and e.id==id and e.value.sceneId 
      end
      local function setProfile(id,_,val) if val then fibaro.profile("activateProfile",id) end return val end
      local function setState(id,_,val) fibaro.call(id,"updateProperty","state",val); return val end
      local function setProps(id,cmd,val) fibaro.call(id,"updateProperty",cmd,val); return val end
      local function profile(id,_) return api.get("/profiles/"..id.."?showHidden=true") end
      local function call(id,cmd) fibaro.call(id,cmd); return true end
      local function set(id,cmd,val) fibaro.call(id,cmd,val); return val end
      local function pushMsg(id,cmd,val) fibaro.alert(fibaro._pushMethod,{id},val,false,''); return val end
      local function set2(id,cmd,val) fibaro.call(id,cmd,table.unpack(val)); return val end
      local function dim2(id,_,val) Util.dimLight(id,table.unpack(val)) end --sec,dir,step,curve,start,stop)
      local mapOr,mapAnd,mapF=table.mapOr,table.mapAnd,function(f,l,s) table.mapf(f,l,s); return true end
      local function child(id,_) for _,c in pairs(quickApp.childDevices) do if c.eid==id then return c end end return nil end

      getFuns={}
      getFuns.value={get,'value',nil,true}
      getFuns.state={get,'state',nil,true}
      getFuns.bat={get,'batteryLevel',nil,true}
      getFuns.power={get,'power',nil,true}
      getFuns.isDead={get,'dead',mapOr,true}
      getFuns.isOn={on,'value',mapOr,true}
      getFuns.isOff={off,'value',mapAnd,true}
      getFuns.isAllOn={on,'value',mapAnd,true}
      getFuns.isAnyOff={off,'value',mapOr,true}
      getFuns.last={last,'value',nil,true}
      getFuns.alarm={alarm,nil,'alarm',true}
      getFuns.armed={function(id) return gp(id).armed end,'armed',mapOr,true}
      getFuns.allArmed={function(id) return gp(id).armed end,'armed',mapAnd,true,true}
      getFuns.disarmed={function(id,_,_) return not gp(id).armed end,'armed',mapAnd,true}
      getFuns.anyDisarmed={function(id,_,_) return not gp(id).armed end,'armed',mapOr,true,false}
      getFuns.alarmBreached={function(id) return gp(id).breached end,'breached',mapOr,true}
      getFuns.alarmSafe={function(id) return not gp(id).breached end,'breached',mapAnd,true}
      getFuns.allAlarmBreached={function(id) return gp(id).breached end,'breached',mapAnd,true}
      getFuns.anyAlarmSafe={function(id) return not gp(id).breached end,'breached',mapOr,true,false}
      getFuns.willArm={function(id) return armedPs[id] end,'willArm',mapOr,true}
      getFuns.allWillArm={function(id) return armedPs[id] end,'willArm',mapAnd,true}
      getFuns.child={child,nil,nil,false}
      getFuns.profile={profile,nil,nil,false}
      getFuns.scene={sae,'sceneActivationEvent',nil,true}
      getFuns.access={ace,'accessControlEvent',nil,true}
      getFuns.central={cce,'centralSceneEvent',nil,true}
      getFuns.safe={off,'value',mapAnd,true}
      getFuns.breached={on,'value',mapOr,true}
      getFuns.isOpen={on,'value',mapOr,true}
      getFuns.isClosed={off,'value',mapAnd,true}
      getFuns.lux={get,'value',nil,true}
      getFuns.volume={get,'volume',nil,true}
      getFuns.position={get,'position',nil,true}
      getFuns.temp={get,'value',nil,true}
      getFuns.coolingThermostatSetpoint={get,'coolingThermostatSetpoint',nil,true}
      getFuns.coolingThermostatSetpointCapabilitiesMax={get,'coolingThermostatSetpointCapabilitiesMax',nil,true}
      getFuns.coolingThermostatSetpointCapabilitiesMin={get,'coolingThermostatSetpointCapabilitiesMin',nil,true}
      getFuns.coolingThermostatSetpointFuture={get,'coolingThermostatSetpointFuture',nil,true}
      getFuns.coolingThermostatSetpointStep={get,'coolingThermostatSetpointStep',nil,true}
      getFuns.heatingThermostatSetpoint={get,'heatingThermostatSetpoint',nil,true}
      getFuns.heatingThermostatSetpointCapabilitiesMax={get,'heatingThermostatSetpointCapabilitiesMax',nil,true}
      getFuns.heatingThermostatSetpointCapabilitiesMin={get,'heatingThermostatSetpointCapabilitiesMin',nil,true}
      getFuns.heatingThermostatSetpointFuture={get,'heatingThermostatSetpointFuture',nil,true}
      getFuns.heatingThermostatSetpointStep={get,'heatingThermostatSetpointStep',nil,true}
      getFuns.thermostatFanMode={get,'thermostatFanMode',nil,true}
      getFuns.thermostatFanOff={get,'thermostatFanOff',nil,true}
      getFuns.thermostatMode={get,'thermostatMode',nil,true}
      getFuns.thermostatModeFuture={get,'thermostatModeFuture',nil,true}
      getFuns.on={call,'turnOn',mapF,true}
      getFuns.off={call,'turnOff',mapF,true}
      getFuns.play={call,'play',mapF,nil}
      getFuns.pause={call,'pause',mapF,nil}
      getFuns.open={call,'open',mapF,true}
      getFuns.close={call,'close',mapF,true}
      getFuns.stop={call,'stop',mapF,true}
      getFuns.secure={call,'secure',mapF,false}
      getFuns.unsecure={call,'unsecure',mapF,false}
      getFuns.isSecure={on,'secured',mapAnd,true}
      getFuns.isUnsecure={off,'secured',mapOr,true}
      getFuns.name={function(id) return fibaro.getName(id) end,nil,nil,false}
      getFuns.HTname={function(id) return Util.reverseVar(id) end,nil,nil,false}
      getFuns.roomName={function(id) return fibaro.getRoomNameByDeviceID(id) end,nil,nil,false}
      getFuns.trigger={function() return true end,'value',nil,true}
      getFuns.time={get,'time',nil,true}
      getFuns.manual={function(id) return quickApp:lastManual(id) end,'value',nil,true}
      getFuns.start={function(id) return fibaro.scene("execute",{id}) end,"",mapF,false}
      getFuns.kill={function(id) return fibaro.scene("kill",{id}) end,"",mapF,false}
      getFuns.toggle={call,'toggle',mapF,true}
      getFuns.wake={call,'wakeUpDeadDevice',mapF,true}
      getFuns.removeSchedule={call,'removeSchedule',mapF,true}
      getFuns.retryScheduleSynchronization={call,'retryScheduleSynchronization',mapF,true}
      getFuns.setAllSchedules={call,'setAllSchedules',mapF,true}
      getFuns.levelIncrease={call,'startLevelIncrease',mapF,nil}
      getFuns.levelDecrease={call,'startLevelDecrease',mapF,nil}
      getFuns.levelStop={call,'stopLevelChange',mapF,nil}

      getFuns.dID={function(a,e) 
          if type(a)=='table' then
            local id = e.event and e.event.id
            if id then for _,id2 in ipairs(a) do if id == id2 then return id end end end
          end
          return a
        end,'<nop>',nil,true}

      getFuns.lock=getFuns.secure
      getFuns.unlock=getFuns.unsecure
      getFuns.isLocked=getFuns.isSecure
      getFuns.isUnlocked=getFuns.isUnsecure 

      setFuns={}
      setFuns.R={set,'setR'}
      setFuns.G={set,'setG'}
      setFuns.B={set,'setB'}
      setFuns.W={set,'setW'}
      setFuns.value={set,'setValue'}
      setFuns.state={setState,'setState'}
      setFuns.alarm={setAlarm,'setAlarm'}
      setFuns.armed={setAlarm,'setAlarm'}
      setFuns.profile={setProfile,'setProfile'}
      setFuns.time={set,'setTime'}
      setFuns.power={set,'setPower'}
      setFuns.targetLevel={set,'setTargetLevel'}
      setFuns.interval={set,'setInterval'}
      setFuns.mode={set,'setMode'}
      setFuns.setpointMode={set,'setSetpointMode'}
      setFuns.defaultPartyTime={set,'setDefaultPartyTime'}
      setFuns.scheduleState={set,'setScheduleState'}
      setFuns.color={set2,'setColor'}
      setFuns.volume={set,'setVolume'}
      setFuns.position={set,'setPosition'}
      setFuns.positions={setProps,'availablePositions'}
      setFuns.mute={set,'setMute'}
      setFuns.thermostatSetpoint={set2,'setThermostatSetpoint'}
      setFuns.thermostatMode={set,'setThermostatMode'}
      setFuns.heatingThermostatSetpoint={set,'setHeatingThermostatSetpoint'}
      setFuns.coolingThermostatSetpoint={set,'setCoolingThermostatSetpoint'}
      setFuns.thermostatFanMode={set,'setThermostatFanMode'}
      setFuns.schedule={set2,'setSchedule'}
      setFuns.dim={dim2,'dim'}
      fibaro._pushMethod = 'push'
      setFuns.msg={pushMsg,"push"}
      setFuns.defemail={set,'sendDefinedEmailNotification'}
      setFuns.btn={set,'pressButton'} -- ToDo: click button on QA?
      setFuns.email={function(id,_,val) local _,_ = val:match("(.-):(.*)"); fibaro.alert('email',{id},val) return val end,""}
      setFuns.start={function(id,_,val) 
          if isEvent(val) then quickApp:postRemote(id,val) else fibaro.scene("execute",{id},val) return true end 
        end,""}

      self.getFuns=getFuns
      self.setFuns=setFuns
    end --- get/set functions

    local function ID(id,i,l) 
      if tonumber(id)==nil then 
        error(format("bad deviceID '%s' for '%s' '%s'",id,i[1],tojson(l or i[4] or "").."?"),3) else return id
      end
    end

    instr['%prop'] = function(s,_,e,i) local id,f=s.pop(),getFuns[i[3]]
      if i[3]=='dID' then s.push(getFuns['dID'][1](id,e)) return end
      if not f then f={_getFun,i[3]} end
      if type(id)=='table' then 
        local l = (f[3] or map)(function(id0) return f[1](ID(id0,i,e._lastR),f[2],e) end,id)
        s.push(l)
      else s.push(f[1](ID(id,i,e._lastR),f[2],e)) end
    end

    instr['%setprop'] = function(s,_,e,i) local id,val,prop=s.pop(),getArg(s,i[3]),getArg(s,i[4])
      local f = setFuns[prop] _assert(f,"bad property '%s'",prop or "") 
      local vp = 0
      local vf = prop=="value" and type(val) == 'table' and type(id)=='table' and val[1]~=nil and function() vp=vp+1 return val[vp] end or function() return val end 
      if type(id)=='table' then table.mapf(function(id0) f[1](ID(id0,i,e._lastR),f[2],vf(),e) end,id); s.push(true)
      else s.push(f[1](ID(id,i,e._lastR),f[2],val,e)) end
    end

    instr['%rule'] = function(s,_,e,_) local b,h=s.pop(),s.pop(); s.push(Rule.compRule({'=>',h,b,e.log},e)) end
    instr['log'] = function(s,n,e) s.push(userLogFunction(e.rule,table.unpack(s.lift(n)))) end
    instr['%logRule'] = function(s,_,_,_) local src,res = s.pop(),s.pop() 
      Debug(_debugFlags.rule or (_debugFlags.ruleTrue and res),"[%s]>>'%s'",tojson(res),src) s.push(res) 
      if res then fibaro.EM.stats.success = (fibaro.EM.stats.success or 0)+1
      else fibaro.EM.stats.fail = (fibaro.EM.stats.fail or 0)+1 end
    end
    instr['%statRule'] = function(s,_,_,_) local res = s.pop()
      if res then fibaro.EM.stats.success = (fibaro.EM.stats.success or 0)+1
      else fibaro.EM.stats.fail = (fibaro.EM.stats.fail or 0)+1 end
      s.push(res) 
    end

-- ER funs
    local simpleFuns={num=tonumber,str=tostring,idname=Util.reverseVar,time=toTime,['type']=type,
      tjson=safeEncode,fjson=json.decode}
    for n,f in pairs(simpleFuns) do instr[n]=function(s,_,_,_) return s.push(f(s.pop())) end end

    instr['sunset']=function(s,_,_,_) s.push(toTime(fibaro.getValue(1,'sunsetHour'))) end
    instr['sunrise']=function(s,_,_,_) s.push(toTime(fibaro.getValue(1,'sunriseHour'))) end
    instr['midnight']=function(s,_,_,_) s.push(midnight()) end
    instr['dawn']=function(s,_,_,_) s.push(toTime(fibaro.getValue(1,'dawnHour'))) end
    instr['dusk']=function(s,_,_,_) s.push(toTime(fibaro.getValue(1,'duskHour'))) end
    instr['now']=function(s,_,_,_) s.push(os.time()-midnight()) end
    instr['wnum']=function(s,_,_,_) s.push(fibaro.getWeekNumber(os.time())) end
    instr['%today']=function(s,_,_,_) s.push(midnight()+s.pop()) end
    instr['%nexttime']=function(s,_,_,_) local t=s.pop()+midnight(); s.push(t >= os.time() and t or t+24*3600) end
    instr['%plustime']=function(s,_,_,_) s.push(os.time()+s.pop()) end
    instr['HM']=function(s,_,_,_) local t = s.pop(); s.push(os.date("%H:%M",t < os.time() and t+midnight() or t)) end  
    instr['HMS']=function(s,_,_,_) local t = s.pop(); s.push(os.date("%H:%M:%S",t < os.time() and t+midnight() or t)) end  
    instr['sign'] = function(s,_) s.push(tonumber(s.pop()) < 0 and -1 or 1) end
    instr['rnd'] = function(s,n) local ma,mi=s.pop(),n>1 and s.pop() or 1 s.push(math.random(mi,ma)) end
    instr['round'] = function(s,_) local v=s.pop(); s.push(math.floor(v+0.5)) end
    instr['sum'] = function(s,_) local m,res=s.pop(),0 for _,x in ipairs(m) do res=res+x end s.push(res) end 
    instr['average'] = function(s,_) local m,res=s.pop(),0 for _,x in ipairs(m) do res=res+x end s.push(res/#m) end 
    instr['size'] = function(s,_) s.push(#(s.pop())) end
    instr['min'] = function(s,n) s.push(math.min(table.unpack(type(s.peek())=='table' and s.pop() or s.lift(n)))) end
    instr['max'] = function(s,n) s.push(math.max(table.unpack(type(s.peek())=='table' and s.pop() or s.lift(n)))) end
    instr['sort'] = function(s,n) local a = type(s.peek())=='table' and s.pop() or s.lift(n); table.sort(a) s.push(a) end
    instr['match'] = function(s,_) local a,b=s.pop(),s.pop(); s.push(string.match(b,a)) end
    instr['osdate'] = function(s,n) local x,y = s.peek(n-1),(n>1 and s.pop() or nil) s.pop(); s.push(os.date(x,y)) end
    instr['ostime'] = function(s,_) s.push(os.time()) end
    instr['%daily'] = function(s,_,e,i) 
      local ev = e.event or {}
      s.pop()
      if ev.type=='global-variable' or ev.type=='quickvar' then
        Rule.recalcDailys(e.rule)
        s.push(false)
      else s.push(true) end
    end
    instr['%interv'] = function(s,_,_,_) local _ = s.pop(); s.push(true) end
    instr['fmt'] = function(s,n) s.push(string.format(table.unpack(s.lift(n)))) end
    instr['redaily'] = function(s,_,_,_) s.push(Rule.restartDaily(s.pop())) end
    instr['eval'] = function(s,_) s.push(Rule.eval(s.pop(),{print=false})) end
    instr['global'] = function(s,_,_,_)  s.push(api.post("/globalVariables/",{name=s.pop()})) end  
    instr['listglobals'] = function(s,_,_,_) s.push(api.get("/globalVariables/")) end
    instr['deleteglobal'] = function(s,_,_,_) s.push(api.delete("/globalVariables/"..s.pop())) end
    instr['once'] = function(s,n,_,i) 
      if n==1 then local f; i[4],f = s.pop(),i[4]; s.push(not f and i[4]) 
      elseif n==2 then local f,g,e; e,i[4],f = s.pop(),s.pop(),i[4]; g=not f and i[4]; s.push(g) 
        if g then quickApp:cancel(i[5]) i[5]=quickApp:post(function() i[4]=nil end,e) end
      else local f; i[4],f=os.date("%x"),i[4] or ""; s.push(f ~= i[4]) end
    end

    instr['%always'] = function(s,n,_,_) local v = s.pop(n) s.push(v or true) end
    instr['enable'] = function(s,n,e,_) 
      if n == 0 then 
        fibaro.EM.enable(e.rule) 
        s.push(true) 
        return 
      end
      local t,g = s.pop(),false; if n==2 then g,t=t,s.pop() end 
      s.push(fibaro.EM.enable(t,g))
    end
    instr['disable'] = function(s,n,e,_) 
      if n == 0 then fibaro.EM.disable(e.rule) s.push(true) return end
      local r = s.pop()
      s.push(fibaro.EM.disable(r)) 
    end
    instr['post'] = function(s,n,ev) 
      local e,t=s.pop(),0; 
      if n==2 then t=e; e=s.pop() end
      local r = quickApp:post(e,t,ev.rule)
      addRuleTimer(ev.rule,r)
      r._prehook = function() clearRuleTimer(ev.rule,r) end
      s.push(r) 
    end
    instr['subscribe'] = function(s,_,_) quickApp:subscribe(s.pop()) s.push(true) end
    instr['publish'] = function(s,n,_) local e,t=s.pop(),nil; if n==2 then t=e; e=s.pop() end quickApp:publish(e,t) s.push(e) end
    instr['remote'] = function(s,n,_) _assert(n==2,"Wrong number of args to 'remote/2'"); 
      local e,u=s.pop(),s.pop(); 
      quickApp:postRemote(u,e) 
      s.push(true) 
    end
    instr['cancel'] = function(s,_) quickApp:cancel(s.pop()) s.push(nil) end
    instr['add'] = function(s,_) local v,t=s.pop(),s.pop() table.insert(t,v) s.push(t) end
    instr['remove'] = function(s,_) local v,t=s.pop(),s.pop() table.remove(t,v) s.push(t) end
    instr['%betw'] = function(s,_) local t2,t1,time=s.pop(),s.pop(),os.time()
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
    instr['again'] = function(s,n,e) 
      local v = n>0 and s.pop() or math.huge
      e.rule._again = (e.rule._again or 0)+1
      if v > e.rule._again then setTimeout(function() e.rule.start(e.rule._event) end,0) else e.rule._again,e.rule._event = nil,nil end
      s.push(e.rule._again or v)
    end
    instr['trueFor'] = function(s,_,e,i)
      local val,time = s.pop(),s.pop()
      e.rule._event = e.event
      local flags = i[5] or {}; i[5]=flags

      if not e.rule.isTrueFor then
        e.rule.isTrueFor = true
        local df = e.rule.disable
        function e.rule.disable() if flags.timer then clearTimeout(flags.timer) flags.timer=nil end df() end
      end

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

    function self.addInstr(name,fun) _assert(instr[name] == nil,"Instr already defined: %s",name) instr[name] = fun end

    self.instr = instr
    local function postTrace(i,args,stack,cp)
      local f,_ = i[1],i[2]
      if not ({jmp=true,push=true,pop=true,addr=true,fn=true,table=true,})[f] then
        local p0,p1=3,1; while i[p0] do table.insert(args,p1,i[p0]) p1=p1+1 p0=p0+1 end
        args = format("%s(%s)=%s",f,safeEncode(args):sub(2,-2),safeEncode(stack.peek()))
        quickApp:debugf("pc:%-3d sp:%-3d %s",cp,stack.size(),args)
      else
        quickApp:debugf("pc:%-3d sp:%-3d [%s/%s%s]",cp,stack.size(),i[1],i[2],i[3] and ","..json.encode(i[3]) or "")
      end
    end

    function self.dump(code)
      code = code or {}
      for p = 1,#code do
        local i = code[p]
        quickApp:debugf("%-3d:[%s/%s%s%s]",p,i[1],i[2] ,i[3] and ","..tojson(i[3]) or "",i[4] and ","..tojson(i[4]) or "")
      end
    end

    function self.listInstructions()
      local t={}
      local doc = QuickApp.ERDoc or {}
      quickApp:debugf("User functions:")
      for f,_ in pairs(instr) do if f=="%" or f:sub(1,1)~='%' then t[#t+1]=f end end
      table.sort(t); for _,f in ipairs(t) do 
        if doc[f] and doc[f] ~= "" then quickApp:debugf("%s%s",f,doc[f]) else __print("['"..f.."'] = \"\"") end --quickApp:debugf(f)  end
      end
      --table.sort(t); for _,f in ipairs(t) do _print("['"..f.."'] = [[]]") end
      quickApp:debugf("Property functions:")
      t={}
      for f,_ in pairs(getFuns) do t[#t+1]="<ID>:"..f end 
      for f,_ in pairs(setFuns) do t[#t+1]="<ID>:"..f.."=.." end 
      table.sort(t); for _,f in ipairs(t) do 
        if doc[f] and doc[f] ~= ""  then quickApp:debugf("%s%s",f,doc[f]) else __print("['"..f.."'] = \"\"") end --quickApp:debugf(f)  end
      end
      --table.sort(t); for _,f in ipairs(t) do _print("['"..f.."'] = [[]]") end
    end

    function self.eval(env)
      local stack,code=env.stack or mkStack(),env.code
      local traceFlag = env.log and env.log.trace or _traceInstrs
      env.cp,env.env,env.src = env.cp or 1, env.env or {},env.src or ""
      local i,args
      local status,stat,res = pcall(function() 
          local stat,res
          while env.cp <= #code and stat==nil do
            i = code[env.cp]
            if traceFlag or _traceInstrs then 
              args = copy(stack.liftc(i[2]))
              stat,res=(instr[i[1]] or instr['%call'])(stack,i[2],env,i)
              postTrace(i,args,stack,env.cp) 
            else stat,res=(instr[i[1]] or instr['%call'])(stack,i[2],env,i) end
            env.cp = env.cp+1
          end --until env.cp > #code or stat
          return stat,res or {stack.pop()}
        end)
      if status then return stat,res
      else
        if isError(stat) then stat.src = stat.src or env.src; error(stat) end
        throwError{msg=format("Error executing instruction:'%s'",tojson(i)),err=stat,src=env.src,ctx=res}
      end
    end

    function self.eval2(env) env.cp=nil; env.locals = env.locals or {}; local _,res=self.eval(env) return res[1] end

    local function makeDateInstr(f)
      return function(s,_,_,i)
        local ts = s.pop()
        if ts ~= i[5] then i[6] = fibaro.dateTest(f(ts)); i[5] = ts end -- cache fun
        s.push(i[6]())
      end
    end

    self.addInstr("date",makeDateInstr(function(s) return s end))             -- min,hour,days,month,wday
    self.addInstr("day",makeDateInstr(function(s) return "* * "..s end))      -- day('1-31'), day('1,3,5')
    self.addInstr("month",makeDateInstr(function(s) return "* * * "..s end))  -- month('jan-feb'), month('jan,mar,jun')
    self.addInstr("wday",makeDateInstr(function(s) return "* * * * "..s end)) -- wday('fri-sat'), wday('mon,tue,wed')

    return self
  end

--------- Event script Rule compiler ------------------------------------------
  local function makeEventScriptRuleCompiler()
    local self = {}; self._rules = {}
    local HOURS24,CATCHUP,RULEFORMAT = 24*60*60,math.huge,"Rule:%s[%s]"
    local map,mapkl,getFuns,midnight,time2str=table.map,table.mapkl,ScriptEngine.getFuns,fibaro.midnight,fibaro.time2str
    local transform,isGlob,isVar,triggerVar = fibaro.utils.transform,Util.isGlob,Util.isVar,Util.triggerVar
    local rule2string = Util.rule2string
    local _macros,dailysTab,rCounter= {},{},0
--    local lblF=function(id,e) return {type='device', id=id, property=format("ui.%s.value",e[3])} end
    local triggFuns={}
    local function isTEvent(e) 
      return type(e)=='table' and (e[1]=='%table' or e[1]=='%quote') and type(e[2])=='table' and e[2].type 
    end

    local function ID(id,p) _assert(tonumber(id),"bad deviceID '%s' for '%s'",id,p or "") return id end
    local ttypes = {
      armed='alarm',alarm='alarm',disarmed='alarm',alarmSafe='alarm',alarmBreached='alarm', 
      allArmed='alarm',anyDisarmed='alarm',anyAlarmSafe='alarm',allAlarmBreached='alarm', 
      willArm='alarm',allWillArm='alarm',
    }
    local gtFuns = {
      ['%daily'] = function(e,s) s.dailys[#s.dailys+1 ]=ScriptCompiler.compile2(e[2]); s.dailyFlag=true end,
      ['%interv'] = function(e,s) s.scheds[#s.scheds+1 ] = ScriptCompiler.compile2(e[2]) end,
      ['%betw'] = function(e,s)
        s.dailys[#s.dailys+1 ]=ScriptCompiler.compile2(e[2])
        s.dailys[#s.dailys+1 ]=ScriptCompiler.compile({'+',1,e[3]}) 
      end,
      ['%var'] = function(e,s) 
        if e[3]=='glob' then s.triggs[e[2] ] = {type='global-variable', name=e[2]} 
        elseif e[3]=='quick' then s.triggs[e[2] ] = {type='quickvar', name=e[2]} 
        elseif triggerVar(e[2]) then s.triggs[e[2] ] = {type='variable', name=e[2]} end 
      end,
      ['%set'] = function(e,_) if isVar(e[2]) and triggerVar(e[2][2]) or isGlob(e[2]) then error("Can't assign variable in rule header") end end,
      ['%prop'] = function(e,s)
        local pn
        if not getFuns[e[3]] then pn = e[3] elseif not getFuns[e[3]][4] then return else pn = getFuns[e[3]][2] end
        local cv = ScriptCompiler.compile2(e[2])
        local v = ScriptEngine.eval2({code=cv})
        local typ = ttypes[e[3]] or 'device'
        local tval = getFuns[e[3]][5] 
        map(function(id) s.triggs[ID(id,e[3])..(pn or '')]={type=typ, id=id, property=pn, value=tval} end,type(v)=='table' and v or {v})
      end,
    }

    local function getTriggers(e0)
      local s={triggs={},dailys={},scheds={},dailyFlag=false}
      local function traverse(e)
        if type(e) ~= 'table' then return e end
        if e[1]== '%eventmatch' then -- {'eventmatch',{'quote', ep,ce}}
          local ce = e[3]
          s.triggs[tojson(ce)] = ce  
        else
          table.mapk(traverse,e)
          if gtFuns[e[1]] then gtFuns[e[1]](e,s)
          elseif triggFuns[e[1]] then
            local cv = ScriptCompiler.compile2(e[2])
            local v = ScriptEngine.eval2({code=cv})
            map(function(id) s.triggs[id]=triggFuns[e[1]](id,e) end,type(v)=='table' and v or {v})
          end
        end
      end
      traverse(e0); return mapkl(function(_,v) return v end,s.triggs),s.dailys,s.scheds,s.dailyFlag
    end

    function self.test(s) return {getTriggers(ScriptCompiler.parse(s))} end
    function self.define(name,fun) ScriptEngine.define(name,fun) end
    function self.addTrigger(name,instr,gt) ScriptEngine.addInstr(name,instr) triggFuns[name]=gt end

    local function compTimes(cs)
      local t1,t2=map(function(c) return ScriptEngine.eval2({code=c}) end,cs),{}
      if #t1>0 then transform(t1,function(t) t2[t]=true end) end
      return mapkl(function(k,_) return k end,t2)
    end

    local function remapEvents(obj)
      if isTEvent(obj) then 
        local ce = ScriptEngine.eval2({code=ScriptCompiler.compile(obj)})
        local ep = fibaro.EM.compilePattern(ce)
        obj[1],obj[2],obj[3]='%eventmatch',ep,ce; 
--    elseif type(obj)=='table' and (obj[1]=='%and' or obj[1]=='%or' or obj[1]=='trueFor') then remapEvents(obj[2]); remapEvents(obj[3])  end
      elseif type(obj)=='table' then map(function(e) remapEvents(e) end,obj,2) end
    end

    local function trimRule(str)
      local str2 = str:sub(1,(str:find("\n") or math.min(#str,_RULELOGLENGTH or 80)+1)-1)
      if #str2 < #str then str2=str2.."..." end
      return str2
    end

    local coroutine = Util.coroutine
    local function compileAction(a,src,log)
      if type(a)=='string' or type(a)=='table' then        -- EventScript
        src = src or a
        local code = type(a)=='string' and ScriptCompiler.compile(src,log) or a
        local function run(env)
          env=env or {}; env.log = env.log or {}; env.log.cont=env.log.cont or function(...) return ... end
          env.locals = env.locals or {}
          for k,v in pairs(env.p or {}) do env.locals[k]={v} end
          local co = coroutine.create(code,src,env); env.co = co
          local res={coroutine.resume(co)}
          if res[1]==true then
            if coroutine.status(co)=='dead' then 
              return env.log.cont(select(2,table.unpack(res))) 
            end
          elseif isError(res[1]) then error(res[1].err)
          else error(res[2]) end
        end
        return run
      else return nil end
    end

    function self.compRule(e,env)
      local head,body,_,res,events,src,triggers2,sdaily = e[2],e[3],e[4],{},{},env.src or "<no src>",{}
      local rRep,rDaily
      src=format(RULEFORMAT,rCounter+1,trimRule(src))
      remapEvents(head)  -- #event -> eventmatch
      local triggers,dailys,reps,dailyFlag = getTriggers(head)
      _assert(#triggers>0 or #dailys>0 or #reps>0, "no triggers found in header")
      --_assert(not(#dailys>0 and #reps>0), "can't have @daily and @@interval rules together in header")
      local code = ScriptCompiler.compile({'%and',(_debugFlags.rule or _debugFlags.ruleTrue) and {'%logRule',head,src} or {'%statRule',head},body},env.log)
      local action = compileAction(code,src,env.log)
      if #reps>0 then -- @@interval rules
        local event,env2={type=fibaro.utils.gensym("INTERV")},{code=reps[1]}
        events[#events+1] = quickApp:event(event,action,src)
        rRep = events[#events]
        event._sh=true
        local timeVal,skip = os.time(),ScriptEngine.eval2(env2)
        local function interval()
          --timeVal = timeVal or os.time()
          quickApp:post(event)
          timeVal = timeVal+math.abs(ScriptEngine.eval2(env2))
          setTimeout(interval,1000*(timeVal-os.time()))
        end
        setTimeout(interval,1000*(skip < 0 and -skip or 0))
      else
        if #dailys > 0 then -- daily rules
          local event={type=fibaro.utils.gensym("DAILY"),_sh=true}
          sdaily={dailys=dailys,event=event,timers={}}
          dailysTab[#dailysTab+1] = sdaily
          events[#events+1]=quickApp:event(event,action,src)
          rDaily = events[#events]
          self.recalcDailys({dailys=sdaily,src=src},true) -- Schedule daily for today
          --local reaction = function() self.recalcDailys(res) end
          for _,tr in ipairs(triggers) do -- Add triggers to reschedule dailys when variables change...
            if tr.type=='global-variable' or tr.type=='quickvar' then 
              events[#events+1]=quickApp:event(tr,action,src) 
              triggers2[tr]=events[#events]
            end
          end
        end
        if not dailyFlag and #triggers > 0 then -- id/glob trigger or events
          for _,tr in ipairs(triggers) do 
            if tr.property~='<nop>' then 
              events[#events+1]=quickApp:event(tr,action,src) 
              triggers2[tr]=events[#events]
            end
          end
        end
      end
      res=#events>1 and fibaro.EM.comboEvent(src,action,events,src) or events[1]
      res.dailys = sdaily
      if sdaily then sdaily.rule=res end

      function res.print() 
        local opts = {table="border=1 bgcolor='green'"}
        quickApp:debug(Util.htmlTable({res.rule2str()},opts)) 
      end
      function res.rule2str() return table.concat(rule2string(res,compTimes),"\n") end

      res.timers,res.triggers,res.reps,res.rep,res.daily={},triggers2,reps,rRep,rDaily
      res.index = rCounter+1
      for _,r in ipairs(res.subs or {}) do r.timers = {} end
      self._rules[rCounter+1]=res
      rCounter=rCounter+1
      return res
    end

-- context = {log=<bool>, level=<int>, line=<int>, doc=<str>, trigg=<bool>, enable=<bool>}
    function self.eval(escript2,log)
      assert(type(escript2)=='string',"rule must be of type 'string' to eval(rule)")
      local escript = escript2:gsub("(\xC2\xA0)","")
      if escript2 ~= escript and not _debugFlags.ignoreInvisibleChars then 
        quickApp:warningf("String contains illegal chars: %s",escript2:gsub("(\xC2\xA0)","<*>")) 
      end
      if log == nil then log = quickApp.ruleOpts or {} elseif log==true then log={print=true} end
      if log.print==nil then log.print=true end
      local status,res
      status, res = pcall(function() 
          local expr = self.macroSubs(escript)
          if not log.cont then 
            log.cont=function(res0)
              log.cont=nil
              local name,r
              if not log.print then return res0 end
              if fibaro.EM.isRule(res0) then name,r=res0.doc,"OK" else name,r=escript,res0 end
              quickApp:debugf("%s = %s",name,tostring(r))
              return res0
            end
          end
          local f = compileAction(expr,nil,log)
          return f({log=log,rule={cache={}, timers={}}})
        end)
      if not status then 
        if not isError(res) then res={ERR=true,ctx=res.ctx,src=escript,err=res} end
        quickApp:errorf("Error in '%s': %s",res and res.src or "rule",trimError(res.err))
        if res.ctx then quickApp:errorf("\n%s",res.ctx) end
        error(res.err or "error eval")
      else return res end
    end

    function self.load(rules2,log)
      local function splitRules(rules)
        local lines,cl,pb,cline = {},math.huge,false,""
        if not rules:match("([^%c]*)\r?\n") then return {rules} end
        rules:gsub("([^%c]*)\r?\n?",function(p) 
            if p:match("^%s*---") then return end
            local s,l = p:match("^(%s*)(.*)")
            if l=="" then cl = math.huge return end
            if #s > cl then cline=cline.." "..l cl = #s pb = true
            elseif #s == cl and pb then cline=cline.." "..l
            else if cline~="" then lines[#lines+1]=cline end cline=l cl=#s pb = false end
          end)
        lines[#lines+1]=cline
        return lines
      end
      map(function(r) self.eval(r,log) end,splitRules(rules2))
    end

    function self.macro(name,str) _macros['%$'..name..'%$'] = str end
    function self.macroSubs(str)
      for m,s in pairs(_macros) do 
        str = str:gsub(m,s) 
      end 
      return str 
    end

    function self.recalcDailys(r,catch)
      if r==nil and catch==nil then
        for _,d in ipairs(dailysTab) do self.recalcDailys(d.rule) end
        return
      end
      if not r.dailys then return end
      local dailys,newTimers,oldTimers,max = r.dailys,{},r.dailys.timers,math.max
      for _,t in ipairs(oldTimers) do quickApp:cancel(t[2]) end
      dailys.timers = newTimers
      local tf,times,m,ot,catchup1,catchup2 = false,compTimes(dailys.dailys),midnight(),os.time()
      for i,t in ipairs(times) do _assert(tonumber(t),"@time not a number:%s",t)
        t = math.floor(t+0.5)
        if t~=CATCHUP then tf=true end
        if t <= 3600*24 or t == CATCHUP then 
          local oldT = oldTimers[i] and oldTimers[i][1]
          if t ~= CATCHUP then
            if _MIDNIGHTADJUST and t==HOURS24 then t=t-1 end
            if t+m >= ot then 
              Debug(oldT ~= t and _debugFlags.dailys,"Rescheduling daily %s for %s",r.src or "",os.date("%c",t+m)); 
              newTimers[#newTimers+1]={t,quickApp:post(dailys.event,max(os.time(),t+m),r.src)}
            else catchup1=true end
          else catchup2 = true end
        end
      end
      if not tf then quickApp:errorf("No time in @<expr> for %s",r.src) end
      if catch and catchup2 and catchup1 then quickApp:tracef("Catching up:%s",r.src); quickApp:post(dailys.event) end
      return r
    end

    -- Scheduler that every night posts 'daily' rules
    Util.defvar('dayname',os.date("%a"))
    quickApp:event({type='%MIDNIGHT'},function(env) 
        Util.defvar('dayname',os.date("*t").wday)
        for _,d in ipairs(dailysTab) do self.recalcDailys(d.rule) end 
        quickApp:post(env.event,"n/00:00")
      end)
    quickApp:post({type='%MIDNIGHT',_sh=true},"n/00:00")
    return self
  end -- makeEventScriptRuleCompiler

  function quickApp:printTagAndColor(tag,color,fmt,...)
    assert(fmt,"print needs tag, color, and args")
    fmt = string.format(fmt,...)
    local t = __TAG
    __TAG = tag or __TAG
    if hc3_emulator or not color then self:tracef(fmt,...) 
    else
      self:trace("<font color="..color..">"..fmt.."</font>") 
    end
    __TAG = t
  end

--- SceneActivation constants
  Util.defvar('S1',Util.S1)
  Util.defvar('S2',Util.S2)
  Util.defvar('catch',math.huge)
  Util.defvar("defvars",Util.defvars)
  Util.defvar("mapvars",Util.reverseMapDef)
  Util.defvar("print",function(...) quickApp:printTagAndColor(...) end)
  Util.defvar("QA",quickApp)

  ScriptParser   = makeEventScriptParser()
  ScriptCompiler = makeEventScriptCompiler(ScriptParser)
  ScriptEngine   = makeEventScriptRuntime()
  Rule           = makeEventScriptRuleCompiler() 
  Rule.ScriptParser   = ScriptParser
  Rule.ScriptCompiler = ScriptCompiler
  Rule.ScriptEngine   = ScriptEngine
  function quickApp:evalScript(...) return Rule.eval(...) end
  Module.eventScript.inited = Rule
  return Rule
end
----------------- Node-red support ----------------------------
Module.nodered={ name = "ER Nodered", version="0.5" }
function Module.nodered.init(self)
  if Module.nodered.inited then return Module.nodered.inited end
  Module.nodered.inited = true 

  local nr = { _nrr = {}, _timeout = 4000, _last=nil }
  local isEvent,asyncCall,receiveAsync = fibaro.EM.isEvent,Util.asyncCall,Util.receiveAsync
  function nr.connect(url) 
    local self2 = { _url = url, _http=netSync.HTTPClient("Nodered") }
    function self2.post(event,sync)
      _assert(isEvent(event),"Arg to nodered.post is not an event")
      local tag, res
      if sync then tag,res = asyncCall("NodeRed",50000) end
      event._transID = tag
      event._from = fibaro.ID
      event._async = true
      event._IP = fibaro.getIPaddress()
      if hc3_emulator then event._IP=event._IP..":"..hc3_emulator.webPort end
      local params =  {options = {
          headers = {['Accept']='application/json',['Content-Type']='application/json'},
          data = json.encode(event), timeout=4000, method = 'POST'},
      }
      self2._http:request(self2._url,params)
      return sync and res or true
    end
    nr._last = self2
    return self2
  end

  function nr.post(event,sync)
    _assert(nr._last,"Missing nodered URL - run Nodered.connect(<url>)")
    return nr._last.post(event,sync)
  end

  function self:fromNodeRed(ev)
    ev = type(ev)=='string' and json.decode(ev) or ev
    local tag = ev._transID
    ev._IP,ev._async,ev._from,ev._transID=nil,nil,nil,nil
    if tag then return receiveAsync(tag,ev)
    else self:post(ev) end
  end
  Nodered = nr
  Module.nodered.inited = nr
  return nr
end -- Nodered

local modules = {
  "utilities","autopatch","device","extras","eventScript","nodered",--"doc"
}

----------------- Main ----------------------------------------
local _version = "v"..QuickApp.E_VERSION.." "..QuickApp.E_FIX

function QuickApp:enableTriggerType(triggers) fibaro.enableSourceTriggers(triggers) end

QuickApp._SILENT = true
function QuickApp:onInit()
  Module['utilities'].init(self)
  self:setVersion("EventRunner4",self.E_SERIAL,self.E_VERSION)
  Util.printBanner("%s, deviceId:%s, version:%s",{self.name,self.id,self.E_VERSION})
  for f,v in pairs(_debugFlags) do fibaro.debugFlags[f]=v end
  _debugFlags = fibaro.debugFlags
  for _,name in ipairs(modules) do
    if not Module[name].inited then Module[name].init(self) end 
  end
  Util.defvar("E_VERSION",QuickApp.E_VERSION)
  Util.defvar("E_FIX",QuickApp.E_FIX)
  fibaro.ID = self.id
  local s = fibaro._orgToString({})
  if not s:match("%s(.*)") then
    self:errorf("Bad table tostring: %s",s)
    os.exit()
  end
  --psys("IP address:%s",Util.getIPaddress())
  local main = self.main
  local _IPADDRESS = fibaro.getIPaddress()
  self:debug("IP:",_IPADDRESS)
  self.main = function(self)
    fibaro.utils.notify("info","Started "..os.date("%c"),true)
    self:tracef("Sunrise:%s,  Sunset:%s",(fibaro.get(1,"sunriseHour")),(fibaro.get(1,"sunsetHour")))
    local uptime,silent = api.get("/settings/info").serverStatus or os.time()
    self:tracef("HC3 running since %s",os.date("%c",uptime))
    Util.printBanner("Setting up rules (main)")
    local startupTime = os.clock()
    local stat,res = pcall(function()
        silent = main(quickApp) -- call main
      end)
    if not stat then
      res=trimError(res)
      self:setView("ERname","text","Error in main()")
      self:error("Main() ERROR:"..res)
      error()
    end
    self:tracef("main finished in %.3fs",os.clock()-startupTime)
    if silent~='silent' then Util.printBanner("Running") end
    self:setView("ERname","text","EventRunner4 %s",_version)
    quickApp:post({type='%startup%',_sh=true})
    quickApp:post({type='_startup_',_sh=true})
    if os.time()-uptime < 30 then quickApp:post({type='se-start',_sh=true}) end
    local currDST = os.date("*t").isdst
    self:addHourTask(function()
        local dst = os.date("*t").isdst
        if dst ~= currDST then
          currDST = dst
          fibaro.post({type='DST_changed'})
        end
      end)
  end
  self:main()
end