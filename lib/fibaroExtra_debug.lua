_MODULES = _MODULES or {} -- Global
_MODULES.debug={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local debugFlags,utils,format = fibaro.debugFlags,fibaro.utils,string.format
    local function setDefault(v1,v2) if v1==nil then return v2 else return v1 end end

    local fformat
    debugFlags.debugLevel=nil
    debugFlags.traceLevel=nil
    debugFlags.notifyError=setDefault(debugFlags.notifyError,true)
    debugFlags.notifyWarning=setDefault(debugFlags.notifyWarning,true)
    debugFlags.onaction=setDefault(debugFlags.onaction,true)
    debugFlags.uievent=setDefault(debugFlags.uievent,true)
    debugFlags.json=setDefault(debugFlags.json,true)
    debugFlags.html=setDefault(debugFlags.html,true)
    debugFlags.reuseNotifies=setDefault(debugFlags.reuseNotifies,true)
    debugFlags.logTrigger=setDefault(debugFlags.logTrigger,true)

-- Add notification to notification center
    local cachedNots = {}
    local function notify(priority, text, reuse)
      local id = plugin.mainDeviceId
      local name = quickApp and quickApp.name or "Scene"
      assert(({info=true,warning=true,alert=true})[priority],"Wrong 'priority' - info/warning/alert")
      local title = text:match("(.-)[:%s]") or format("%s deviceId:%d",name,id)

      if reuse==nil then reuse = debugFlags.reuseNotifies end
      local msgId = nil
      local data = {
        canBeDeleted = true,
        wasRead = false,
        priority = priority,
        type = "GenericDeviceNotification",
        data = {
          sceneId = sceneId,
          deviceId = id,
          subType = "Generic",
          title = title,
          text = tostring(text)
        }
      }
      local nid = title..id
      if reuse then
        if cachedNots[nid] then
          msgId = cachedNots[nid]
        else
          for _,n in ipairs(api.get("/notificationCenter") or {}) do
            if n.data and (n.data.deviceId == id or n.data.sceneeId == id) and n.data.title == title then
              msgId = n.id; break
            end
          end
        end
      end
      if msgId then
        api.put("/notificationCenter/"..msgId, data)
      else
        local d = api.post("/notificationCenter", data)
        if d then cachedNots[nid] = d.id end
      end
    end
    utils.notify = notify

    local oldPrint = print
    local inhibitPrint = {['onAction: ']='onaction', ['UIEvent: ']='uievent'}
    function print(a,...) 
      if not inhibitPrint[a] or debugFlags[inhibitPrint[a]] then
        oldPrint(a,...) 
      end
    end

    local htmlCodes={['\n']='<br>', [' ']='&nbsp;'}
    local function fix(str) return str:gsub("([\n%s])",function(c) return htmlCodes[c] or c end) end
    local function htmlTransform(str)
      local hit = false
      str = str:gsub("([^<]*)(<.->)([^<]*)",function(s1,s2,s3) hit=true
          return (s1~="" and fix(s1) or "")..s2..(s3~="" and fix(s3) or "") 
        end)
      return hit and str or fix(str)
    end

    function fformat(fmt,...)
      local args = {...}
      if #args == 0 then return tostring(fmt) end
      for i,v in ipairs(args) do if type(v)=='table' then args[i]=tostring(v) end end
      return (debugFlags.html and not hc3_emulator) and htmlTransform(format(fmt,table.unpack(args))) or format(fmt,table.unpack(args))
    end
    fibaro.fformat = fformat

    local function arr2str(del,...)
      local args,res = {...},{}
      for i=1,#args do if args[i]~=nil then res[#res+1]=tostring(args[i]) end end 
      return (debugFlags.html and not hc3_emulator) and htmlTransform(table.concat(res,del)) or table.concat(res,del)
    end 
    fibaro.arr2str = arr2str

    fibaro.stringTrunc = { 100, 160, 1000 }
    local function print_debug(typ,tag,str)
      --__fibaro_add_debug_message(tag or __TAG,str or "",typ or "debug")
      local m,s=str:match("^##(%d)(.*)") -- truncate output
      if m then 
        str=s
        local sl,ml = str:len()-3,fibaro.stringTrunc[tonumber(m)]
        if ml and sl > ml then str=str:sub(1,ml).."..." end
      end
      if type(tag)=='number' then tag = nil end
      __fibaro_add_debug_message(tag or __TAG, str, typ)
      --api.post("/debugMessages",{message=str,messageType=typ or "debug",tag=tag or __TAG})
      if typ=='error' and debugFlags.eventError then
        fibaro.post({type='error',message=str,tag=tag})
      elseif typ=='warning' and debugFlags.eventWarning then
        fibaro.post({type='warning',message=str,tag=tag})
      end
      return str
    end

    function fibaro.debug(tag,...) 
      if not(type(tag)=='number' and tag > (debugFlags.debugLevel or 0)) then 
        return print_debug('debug',tag,arr2str(" ",...)) 
      else return "" end 
    end
    function fibaro.trace(tag,a,...)
      if a and inhibitPrint[a] and debugFlags[inhibitPrint[a]]==false then return end
      if not(type(tag)=='number' and tag > (debugFlags.traceLevel or 0)) then 
        return print_debug('trace',tag,arr2str(" ",a,...)) 
      else return "" end 
    end
    function fibaro.error(tag,...)
      local str = print_debug('error',tag,arr2str(" ",...))
      if debugFlags.notifyError then notify("alert",str) end
      return str
    end
    function fibaro.warning(tag,...) 
      local str = print_debug('warning',tag,arr2str(" ",...))
      if debugFlags.notifyWarning then notify("warning",str) end
      return str
    end
    function fibaro.debugf(tag,fmt,...) 
      if not(type(tag)=='number' and tag > (debugFlags.debugLevel or 0)) then 
        return print_debug('debug',tag,fformat(fmt,...)) 
      else return "" end 
    end
    function fibaro.tracef(tag,fmt,...) 
      if not(type(tag)=='number' and tag > (debugFlags.traceLevel or 0)) then 
        return print_debug('trace',tag,fformat(fmt,...)) 
      else return "" end 
    end
    function fibaro.errorf(tag,fmt,...)
      local str = print_debug('error',tag,fformat(fmt,...)) 
      if debugFlags.notifyError then notify("alert",str) end
      return str
    end
    function fibaro.warningf(tag,fmt,...) 
      local str = print_debug('warning',tag,fformat(fmt,...)) 
      if debugFlags.notifyWarning then notify("warning",str) end
      return str
    end

    for _,f in ipairs({'debugf','tracef','warningf','errorf'}) do
      fibaro[f] = fibaro.protectFun(fibaro[f],f,2)
    end

  end -- Debug functions
} -- Debug functions

