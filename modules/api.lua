--[[
TQAE - Tiny QuickApp emulator for the Fibaro Home Center 3
Copyright (c) 2021 Jan Gabrielsson
Email: jan@gabrielsson.com
MIT License

Module REST api calls. Both for local emulator calls and external REST calls from the HC3. Uses the Webserver module

--]]
local EM,FB = ...

local json = FB.json
local HC3Request,LOG,DEBUG,Devices = EM.HC3Request,EM.LOG,EM.DEBUG,EM.Devices
local __fibaro_call,__assert_type=FB.__fibaro_call,FB.__assert_type
local copy,cfg = EM.utilities.copy,EM.cfg

LOG.register("api","Log api.* related events")

local GUI_HANDLERS = {
  ["GET/api/callAction"] = function(_,client,ref,_,opts)
    local args = {}
    local id,action = tonumber(opts.deviceID),opts.name 
    for k,v in pairs(opts) do
      if k:sub(1,3)=='arg' then args[tonumber(k:sub(4))]=v end
    end
    local stat,err=pcall(FB.__fibaro_call,id,action,"",{args=args})
    if not stat then LOG.error("Bad callAction:%s",err) end
    client:send("HTTP/1.1 302 Found\nLocation: "..ref.."\n\n")
    return true
  end,
  --[[
    {
  "args": ["{}","{}"],
  "delay": 30,
  "integrationPin": "1234"
}
--]]
--  ["POST/api/devices/#id/action/#name"] = function(_,client,ref,data,opts,id,action)
--    local args = json.decode(data)
--    local params = args.args or {}
--    local stat,err=pcall(FB.__fibaro_call,id,action,"",{args=params})
--    if not stat then LOG.error("Bad callAction:%s",err) end
--    client:send("HTTP/1.1 302 Found\nLocation: "..(ref or "").."\n\n")
--    return true
--  end,

  ["GET/TQAE/method"] = function(_,client,ref,_,opts)
    local arg = opts.Args
    local stat,res = pcall(function()
        arg = json.decode("["..(arg or "").."]")
        --local QA = EM.getQA(tonumber(opts.qaID))
        __fibaro_call(tonumber(opts.qaID),opts.method,"",{args=arg})
        local res={}
        --local res = {QA[opts.method](QA,table.unpack(arg))}
        DEBUG("api","sys","Web call: QA(%s):%s%s = %s",opts.qaID,opts.method,json.encode(arg),json.encode(res))
      end)
    if not stat then 
      LOG.error("Web call: QA(%s):%s%s - %s",opts.qaID,opts.method,json.encode(arg),res)
    end
    client:send("HTTP/1.1 302 Found\nLocation: "..ref.."\n\n")
    return true
  end,
  ["GET/TQAE/setglobal"] = function(_,client,ref,_,opts)
    local name,value = opts.name,opts.value
    FB.fibaro.setGlobalValue(name,tostring(value))
    client:send("HTTP/1.1 302 Found\nLocation: "..(ref or "").."\n\n")
    return true
  end,
  ["GET/TQAE/debugSwitch"] = function(_,client,ref,_,opts)
    EM.debugFlags[opts.name] = not EM.debugFlags[opts.name]
    LOG.sys("debugFlags.%s=%s",opts.name,tostring(EM.debugFlags[opts.name]))
    client:send("HTTP/1.1 302 Found\nLocation: "..(ref or "").."\n\n")
    return true
  end,
  ["GET/TQAE/lua"] = function(_,client,ref,_,opts)
    local code = load(opts.code,nil,"t",{EM=EM,FB=FB})
    code()
    client:send("HTTP/1.1 302 Found\nLocation: "..(ref or "").."\n\n")
    return true
  end,
  ["GET/TQAE/slider/#id/#name/#id"] = function(_,client,ref,_,_,id,slider,val)
    id = tonumber(id)
    local stat,err = pcall(function()
        local qa,env = EM.getQA(id)
        qa:updateView(slider,"value",tostring(val))
        if not qa.parent then
          env.onUIEvent(id,{deviceId=id,elementName=slider,eventType='onChanged',values={tonumber(val)}})
        else 
          local action = qa.uiCallbacks[slider]['onChanged']
          env.onAction(id,{deviceId=id,actionName=action,args={tonumber(val)}})
        end
      end)
    if not stat then LOG.error("%s",err) end
    client:send("HTTP/1.1 302 Found\nLocation: "..ref.."\n\n")
    return true
  end,   
  ["GET/TQAE/button/#id/#name"] = function(_,client,ref,_,_,id,btn)
    id = tonumber(id)
    local stat,err = pcall(function()
        local qa,env = EM.getQA(id)
        if not qa.parent then 
          FB.__fibaro_call_UI(id,btn,'onReleased',{})
          --env.onUIEvent(id,{deviceId=id,elementName=btn,eventType='onReleased',values={}})
        else
          local action = qa.uiCallbacks[btn]['onReleased']
          env.onAction(id,{deviceId=id,actionName=action,args={}})
        end
      end)
    if not stat then LOG.error("%s",err) end
    client:send("HTTP/1.1 302 Found\nLocation: "..(ref or "").."\n\n")
    return true
  end,
  ["POST/TQAE/action/#id"] = function(_,client,ref,body,_,id)
    local args = json.decode(body)
    local _,env = EM.getQA(tonumber(id))
    local ctx = EM.Devices[tonumber(id)]
    if ctx==nil then return end
    EM.setTimeout(function() env.onAction(id,args) end,0,nil,ctx)
    client:send("HTTP/1.1 302 Found\nLocation: "..(ref or "").."\n\n")
  end,
  ["POST/TQAE/ui/#id"] = function(_,client,ref,body,_,id) 
    local _,env = EM.getQA(tonumber(id))
    local args = json.decode(body)
    local ctx = EM.Devices[tonumber(id)]
    if ctx==nil then return end
    EM.setTimeout(function() env.onUIEvent(id,args) end,0,nil,ctx)
    client:send("HTTP/1.1 302 Found\nLocation: "..(ref or "").."\n\n")
  end,
}

EM.EMEvents('start',function(_) EM.processPathMap(GUI_HANDLERS) end)

----------------------

local api = {}
local _fcont={['true']=true,['false']=false}
local function _fconv(s) return _fcont[s]==nil and s or _fcont[s] end
local function member(e,l) for i=1,#l do if e==l[i] then return i end end end
local fFuns = {
  interface=function(v,rsrc) return member(v,rsrc.interfaces or {}) end,
  property=function(v,rsrc) return rsrc.properties[v:match("%[(.-),")]==_fconv(v:match(",(.*)%]")) end
}

local function retCode(rsrc) if  rsrc then return rsrc,200  else return rsrc,404 end end

local function getAllItems(rname)
  local r = cfg.offline and {} or HC3Request("GET","/"..rname)
  for _,v in pairs(EM.rsrc[rname]) do r[#r+1]=v end
  return r,200
end

local function getItem(rname,id)
  if cfg.offline or EM.rsrc[rname][id] then return retCode(EM.rsrc[rname][id])
  elseif cfg.shadow then
    if not EM.rsrc[rname][id] then
      EM.rsrc[rname][id] = HC3Request("GET","/"..rname.."/"..id)
    end
    return retCode(EM.rsrc[rname][id])
  else return HC3Request("GET","/"..rname.."/"..id) end
end

local function createItem(rname,id,data)
  local cfun = rname:sub(1,-2)
  if cfg.offline or cfg.shadow or EM.rsrc[rname][id] then
    if EM.rsrc[rname][id] then return nil,404 
    elseif EM.create[cfun] or EM.create[rname] then
      return (EM.create[cfun] or EM.create[rname])(data),200
    else return nil,501 end
  else return HC3Request("POST","/"..rname,data) end
end

local function modifyItem(rname,id,data)
  if not (cfg.offline or cfg.shadow or EM.rsrc[rname][id]) then return HC3Request("PUT","/"..rname.."/"..id,data) end
  if cfg.shadow and not EM.rsrc[rname][id] then
    EM.rsrc[rname][id] = HC3Request("GET","/"..rname.."/"..id)
  end
  local r = EM.rsrc[rname][id]
  if not r then return nil,404 end
  for k,v in pairs(data) do r[k]=v end
  return r,200
end

local function deleteItem(rname,id)
  if EM.rsrc[rname][id] then
    EM.rsrc[rname][id] = nil
    return nil,200
  else return HC3Request("DELETE","/"..rname.."/"..id,data) end
end

local function filter(list,props)
  if next(props)==nil then return list end
  local res = {}
  for _,rsrc in ipairs(list) do
    local flag = false
    for k,v in pairs(props) do
      if fFuns[k] then flag = fFuns[k](v,rsrc) else flag = rsrc[k]==v end
      if not flag then break end 
    end
    if flag then res[#res+1]=rsrc end
  end
  return res
end

local aHC3call
local API_CALLS = { -- Intercept some api calls to the api to include emulated QAs or emulator aspects
  ["GET/devices"] = function(_,_,_,opts)
    local ds = cfg.offline and {} or HC3Request("GET","/devices") or {}
    for _,dev in pairs(Devices) do ds[#ds+1]=dev.dev end     -- Add emulated Devices
    for _,dev in pairs(EM.rsrc.devices) do ds[#ds+1]=dev end -- Add raw devices
    if next(opts)==nil then
      return ds,200
    else
      return filter(ds,opts),200
    end
  end,
--   api.get("/devices?parentId="..self.id) or {}
  ["GET/devices/#id"] = function(_,path,_,_,id)
    local d = Devices[id] and Devices[id].dev or EM.rsrc.devices[id] 
    if d  then return d,200
    elseif not cfg.offline then return HC3Request("GET",path)
    else return nil,404 end
  end,
  ["GET/devices/#id/properties/#name"] = function(_,path,_,_,id,prop) 
    local d = Devices[id] and Devices[id].dev or EM.rsrc.devices[id] 
    if d then 
      if d.properties[prop]~=nil then return { value = d.properties[prop], modified=0},200 
      else return nil,404 end
    elseif not cfg.offline then return HC3Request("GET",path) end
  end,
  ["POST/devices/#id/action/#name"] = function(_,path,data,_,id,action) 
    return __fibaro_call(tonumber(id),action,path,data) 
  end,
  ["PUT/devices/#id"] = function(_,path,data,id)
    if Devices[id] then
      if data.properties then
        for k,v in pairs(data.properties) do
          FB.put("plugins/updateProperty",{deviceId=id,propertyName=k,value=v})
        end
      end
      return data,202
      -- Should check other device values too - usually needs restart of QA
    elseif not cfg.offline then return HC3Request("GET",path, data)
    else return nil,404 end
  end,

  ["GET/globalVariables"] = function(_,path,_,_) return getAllItems('globalVariables') end,
  ["GET/globalVariables/#name"] = function(_,path,_,_,name) return getItem('globalVariables',name) end,
  ["POST/globalVariables"] = function(_,path,data,_) return createItem('globalVariables',name,data) end,
  ["PUT/globalVariables/#name"] = function(_,path,data,_,name)
    local oldVar  = EM.rsrc.globalVariables[name] or {}
    local oldValue  = oldVar.value
    local res,code  = modifyItem('globalVariables',name,data)
    local var = EM.rsrc.globalVariables[name]
    if cfg.offline or cfg.shadow and code <  205 and oldValue ~= var.value then
      EM.addRefreshEvent({
          type='GlobalVariableChangedEvent',
          created = EM.osTime(),
          data={variableName=name, newValue=var.value, oldValue=oldValue}
        })
    end
    return res,code
  end,
  ["DELETE/globalVariables/#name"] = function(_,path,data,_,name) return deleteItem('globalVariables',name) end,

  ["GET/rooms"] = function(_,path,_,_) return getAllItems('rooms') end,
  ["GET/rooms/#id"] = function(_,path,_,_,id) return getItem('rooms',id) end,
  ["POST/rooms"] = function(_,path,data,_) return createItem('rooms',id,data) end,
  ["POST/rooms/#id/action/setAsDefault"] = function(_,path,data,_,id)
    cfg.defaultRoom = id
    if cfg.offline or cfg.shadow then return id,200 else return HC3Request("POST",path,data) end
  end,
  ["PUT/rooms/#id"] = function(_,path,data,_,id) return modifyItem('rooms',id,data) end,
  ["DELETE/rooms/#id"] = function(_,path,data,_,id) return deleteItem('rooms',id,data) end,

  ["GET/sections"] = function(_,path,_,_) return getAllItems('sections') end,
  ["GET/sections/#id"] = function(_,path,_,_,id) return getItem('sections',id) end,
  ["POST/sections"] = function(_,path,data,_) return createItem('sections',id,data) end,
  ["PUT/sections/#id"] = function(_,path,data,_,id) return modifyItem('sections',id,data) end,
  ["DELETE/sections/#id"] = function(_,path,data,_,id) return deleteItem('sections',id,data) end,

  ["GET/customEvents"] = function(_,path,_,_) return getAllItems('customEvents') end,
  ["GET/customEvents/#name"] = function(_,path,_,name) return getItem('customEvents',name) end,
  ["POST/customEvents"] = function(_,path,data,_) return createItem('customEvents',id,data) end,
  ["POST/customEvents/#name"] = function(_,path,data,_,name)
    if EM.rsrc.customEvents[name] then
      EM.addRefreshEvent({
          type='CustomEvent',
          created = EM.osTime(),
          data={name=name, value=EM.rsrc.customEvents[name].userDescription}
        })
    elseif not cfg.offline then return HC3Request("POST",path,data) 
    else return 404,nil end
  end,
  ["PUT/customEvents/#name"] = function(_,path,data,name) return modifyItem('customEvents',name,data) end,
  ["DELETE/customEvents/#name"] = function(_,path,data,name) return deleteItem('customEvents',name) end,

  ["GET/scenes"] = function(m,path,h,j)
    return HC3Request("GET",path)
  end,
  ["GET/scenes/#id"] = function(_,path,_,_)
    return HC3Request("GET",path)
  end,

  ["POST/plugins/updateProperty"] = function(method,path,data,_)
    local D = Devices[data.deviceId]
    if D then
      local oldVal = D.dev.properties[data.propertyName]
      D.dev.properties[data.propertyName]=data.value 
      EM.addRefreshEvent({
          type='DevicePropertyUpdatedEvent',
          created = EM.osTime(),
          data={id=data.deviceId, property=data.propertyName, newValue=data.value, oldValue=oldVal}
        })
      if D.proxy or D.childProxy then
        return HC3Request(method,path,data)
      else return data.value,202 end
    else
      return HC3Request(method,path,data)
    end
  end,
  ["POST/plugins/updateView"] = function(method,path,data)
    local D = Devices[data.deviceId]
    if D and (D.proxy or D.childProxy) then
      HC3Request(method,path,data)
    end
  end,
  ["POST/plugins/restart"] = function(method,path,data,_)
    if Devices[data.deviceId] then
      EM.restartQA(Devices[data.deviceId])
      return true,200
    else return HC3Request(method,path,data) end
  end,
  ["POST/plugins/createChildDevice"] = function(method,path,props,_)
    local D = Devices[props.parentId]
    if props.initialProperties and next(props.initialProperties)==nil then 
      props.initialProperties = nil
    end
    if not D.proxy then
      local info = {
        parentId=props.parentId,name=props.name,
        type=props.type,properties=props.initialProperties,
        interfaces=props.initialInterfaces,
        timers = D.timers,
        lock = D.lock,
      }
      local dev = EM.createDevice(info)
      Devices[dev.id]=info
      DEBUG("child","sys","Created local child device %s",dev.id)
      dev.parentId = props.parentId
      return dev,200
    else 
      local dev,err = HC3Request(method,path,props)
      if dev then
        DEBUG("child","sys","Created child device %s on HC3",dev.id)
      end
      return dev,err
    end
  end,    
  ["POST/debugMessages"] = function(_,_,args,_)
    local str,tag,typ = args.message,args.tag,args.messageType
    FB.__fibaro_add_debug_message(tag,str,typ)
    return 200
  end,
  ["POST/plugins/publishEvent"] = function(_,_,data,_)
    local id = data.source
    local D = Devices[id]
    if D.proxy or D.childProxy then
      return EM.post2Proxy(id,"/plugins/publishEvent",data)
    else
      return nil,200
    end
  end,
  ["DELETE/plugins/removeChildDevice/#id"] = function(method,path,data,_,id)
    local D = Devices[id]
    if D then
      Devices[id]=nil
      local p = Devices[D.dev.parentId]
      EM.setTimeout(function() EM.restartQA(p) end,0,nil,p) 
      --EM.restartQA(D.dev.parentId)
      if D.childProxy then
        return HC3Request(method,path,data) 
      end
      return true,200
    else return HC3Request(method,path,data) end
  end,

  ["GET/panels/location"] = function(_,path,_,_) return getAllItems('panels/location') end,
  ["GET/panels/location/#id"] = function(_,path,_,_,id) return getItem('panels/location',id) end,
  ["POST/panels/location"] = function(_,path,data,_) return createItem('panels/location',id,data) end,
  ["PUT/panels/location/#id"] = function(_,path,data,_,id) return modifyItem('panels/location',id,data) end,
  ["DELETE/panels/location/#id"] = function(_,path,data,_,id) return deleteItem('panels/location',id,data) end,

  ["GET/users"] = function(_,path,_,_) return getAllItems('users') end,
  ["GET/users/#id"] = function(_,path,_,_,id) return getItem('users',id) end,
  ["POST/users"] = function(_,path,data,_) return createItem('users',id,data) end,
  ["PUT/users/#id"] = function(_,path,data,_,id) return modifyItem('users',id,data) end,
  ["DELETE/users/#id"] = function(_,path,data,_,id) return deleteItem('users',id,data) end,

------------- quickApp ---------
  ["GET/quickApp/#id/files"] = function(method,path,data,_,id)                     --Get files
    local D = Devices[id]
    if D then
      local f,files = D.fileMap or {},{}
      for _,v in pairs(f) do v = copy(v); v.content = nil; files[#files+1]=v end
      return files,200
    else return HC3Request(method,path,data) end
  end,
  ["POST/quickApp/#id/files"] = function(method,path,data,_,id)                        --Create file
    local D = Devices[id]
    if D then
      local f,files = D.fileMap or {},{}
      if f[data.name] then return nil,404 end
      f[data.name] = data
      return data,200
    else return HC3Request(method,path,data) end
  end,
  ["GET/quickApp/#id/files/#name"] = function(method,path,data,_,id,name)         --Get specific file
    local D = Devices[id]
    if D then
      if (D.fileMap or {})[name] then return D.fileMap[name],200
      else return nil,404 end
    else return HC3Request(method,path,data) end
  end,
  ["PUT/quickApp/#id/files/#name"] = function(method,path,data,_,id,name)         --Update specific file
    local D = Devices[id]
    if D then
      if (D.fileMap or {})[name] then
        local args = type(data)=='string' and json.decode(data) or data
        D.fileMap[name] = args
        EM.restartQA(D)
        return D.fileMap[name],200
      else return nil,404 end
    else return HC3Request(method,path,data) end
  end,
  ["PUT/quickApp/#id/files"]  = function(method,path,data,_,id)                  --Update files
    local D = Devices[id]   
    if D then
      local args = type(data)=='string' and json.decode(data) or data
      for _,f in ipairs(args) do
        if D.fileMap[f.name] then D.fileMap[f.name]=f end
      end
      EM.restartQA(D)
      return true,200
    else return HC3Request(method,path,data) end
  end,
  ["GET/quickApp/export/#id"] = function(method,path,data,_,id)                --Export QA to fqa
    local D = Devices[id]
    if D then
      --return QA.toFQA(id,nil),200
    else return HC3Request(method,path,data) end
  end,
  ["POST/quickApp/"] = function(method,path,data)                              --Install QA
    local lcl = FB.__fibaro_local(false)
    local res,err = HC3Request(method,path,data)
    FB.__fibaro_local(lcl)
    return res,err
  end,
  ["DELETE/quickApp/#id/files/#name"]  = function(method,path,data,_,id,name)    -- Delete file
    local D = Devices[id]
    if D then
      if D.fileMap[name] then
        D.fileMap[name]=nil
        EM.restartQA(D)
        return true,200
      else return nil,404 end
    else return HC3Request(method,path,data) end
  end,

  ["GET/plugins/#id/variables"] = function(method,path,data,_,id)   -- get keys
    local D = Devices[id]
    if cfg.offline or D then
      if D then
        D.storage = D.storage or {}

      else return nil, 404 end
    else return HC3Request(method,path) end
  end,
  ["GET/plugins/#id/variables/#name"] = function(method,path,data,_,id,key)   -- get key
    local D = Devices[id]
    if cfg.offline or D then
      if D then
        D.storage = D.storage or {}
        if D.storage[key] then return {name=key,value=D.storage[key],200} else return nil,404 end
      else return nil, 404 end
    else return HC3Request(method,path) end
  end,
  ["POST/plugins/#id/variables"] = function(method,path,data,_,id)   -- create key
    local D = Devices[id]
    if cfg.offline or D then
      if D then
        D.storage = D.storage or {}
        D.storage[data.name]=data.value 
        return true,200
      else return nil, 409 end
    else return HC3Request(method,path,data) end
    --return nil,409
  end,
  ["PUT/plugins/#id/variables"] = function(method,path,data,_,id,key)   -- modify key
    local D = Devices[id]
    if cfg.offline or D then
      if D then
        D.storage = D.storage or {}
        if D.storage[key] then
          D.storage[key] = data.value
          return true,200
        else return nil,404 end
      else return nil,404 end
    else return HC3Request(method,path,data) end
    --return nil,404
  end,
  ["DELETE/plugins/#id/variables/#name"] = function(method,path,data,_,id,name)   -- delete key
    if cfg.offline then
    else return HC3Request(method,path) end
  end,
  ["DELETE/plugins/#id/variables"] = function(method,path,data,_,id,name)   -- delete keys
    if cfg.offline then
    else return HC3Request(method,path) end
  end,

}

local API_MAP={ GET={}, POST={}, PUT={}, DELETE={} }

function aHC3call(method,path,data, remote) -- Intercepts some cmds to handle local resources
--  print(method,path)
  if remote == 'remote' then return HC3Request(method,path,data) end
  local fun,args,opts,path2 = EM.lookupPath(method,path,API_MAP)
  if type(fun)=='function' then
    local stat,res,code = pcall(fun,method,path2,data,opts,table.unpack(args))
    if not stat then return LOG.error("Bad API call:%s",res)
    elseif code~=false then return res,code end
  elseif fun~=nil or cfg.offline then return LOG.error("Bad API call:%s",fun or path) end
  return HC3Request(method,path,data) -- No intercept, send request to HC3
end

-- Normal user calls to api will have pass==nil and the cmd will be intercepted if needed. __fibaro_* will always pass
function api.get(cmd, remote) return aHC3call("GET",cmd, nil, remote) end
function api.post(cmd,data, remote) return aHC3call("POST",cmd,data, remote) end
function api.put(cmd,data, remote) return aHC3call("PUT",cmd,data, remote) end
function api.delete(cmd, remote) return aHC3call("DELETE",cmd, remote) end

local function returnREST(code,res,client,call)
  if not code or code > 205 then 
    LOG.error("API error:%s - %s",code,call) 
    client:send("HTTP/1.1 "..code.." Not Found\n\n")
    return
  end
  local dl,sdata = 0,""
  if type(res)=='table' then
    sdata = json.encode(res)
    dl = #sdata
  end
  client:send("HTTP/1.1 "..code.." OK\n")
  client:send("server: TQAE\n")
  client:send("Content-Length: "..dl.."\n")
  client:send("Content-Type: application/json;charset=UTF-8\n")
  client:send("Cache-control: no-cache, no-store\n")
  client:send("Connection: close\n\n")
  client:send(sdata)
  return true 
end

local function exportAPIcall(p,f)
  if p ~= "GET/api/callAction" then
    local method = p:match("^(.-)/")

    local function fe(path,client,ref,data,opts,...)
      data = data and json.decode(data)
      DEBUG("api","sys","Incoming API call: %s",path)
      local res,code = f(method,path:sub(5),data,opts,...)
      returnREST(code,res,client,path)
    end

    p = p:gsub("^%w+",function(str) return str.."/api" end)
    EM.addPath(p,fe)
  end
end

EM.EMEvents('start',function(_) 
    for p,f in pairs(API_CALLS) do EM.addAPI(p,f) end
    --EM.processPathMap(API_CALLS,API_MAP)

    local f1 = EM.lookupPath("GET","/devices/0",API_MAP)
    function FB.__fibaro_get_device(id) __assert_type(id,"number") return f1("GET","/devices/"..id,nil,{},id) end

    local f2 = EM.lookupPath("GET","/devices",API_MAP)
    function FB.__fibaro_get_devices() return f2("GET","/devices",nil,{}) end

    local f3 = EM.lookupPath("GET","/rooms/0",API_MAP)
    function FB.__fibaro_get_room(id) __assert_type(id,"number") return f3("GET","/rooms/"..id,nil,{},id) end

    local f4 = EM.lookupPath("GET","/scenes/0",API_MAP)
    function FB.__fibaro_get_scene(id) __assert_type(id,"number") return f4("GET","/scenes/"..id,nil,{},id) end

    local f5 = EM.lookupPath("GET","/globalVariables/x",API_MAP)
    function FB.__fibaro_get_global_variable(name) 
      __assert_type(name,"string") return f5("GET","/globalVariables/"..name,nil,{},name) 
    end

    local f6 = EM.lookupPath("GET","/devices/0/properties/x",API_MAP)
    function FB.__fibaro_get_device_property(id,prop) 
      __assert_type(id,"number") __assert_type(prop,"string")
      return f6("GET","/devices/"..id.."/properties/"..prop,nil,{},id,prop) 
    end

    local function filterPartitions(filter)
      local res = {}
      for _,p in ipairs(api.get("/alarms/v1/partitions") or {}) do if filter(p) then res[#res+1]=p.id end end
      return res
    end

    function FB.__fibaro_get_breached_partitions() 
      return api.get("/alarms/v1/partitions/breached")
    end

    -- Intercept unimplemented APIs and redicrect to HC3 if online
    EM.notFoundPath("^.-/api",function(method,path,client,body)
        if cfg.offline then
          DEBUG("api","sys","Error unknown api (offline): %s",path)
          client:send("HTTP/1.1 501 Not Implemented\n\n")
        else
          DEBUG("api","sys","Redirecting unknown api to HC3: %s",path)
          local res,code = HC3Request(method,path:sub(5),body)
          returnREST(code,res,client,path)
        end
      end)

  end) -- start

function EM.addAPI(p,f) EM.addPath(p,f,API_MAP) exportAPIcall(p,f) end -- Add internal API and export as external API

FB.api = api