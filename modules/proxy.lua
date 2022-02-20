--[[
TQAE - Tiny QuickApp emulator for the Fibaro Home Center 3
Copyright (c) 2021 Jan Gabrielsson
Email: jan@gabrielsson.com
MIT License

Proxy support - responsible for creating a proxy of the emulated QA on the HC3

--]]
local EM,FB=...

local LOG,json,api = EM.LOG,FB.json,FB.api
local Devices,HC3Request = EM.Devices,EM.HC3Request
local createQuickApp, updateHC3QAFiles
local function copy(t) local r ={}; for k,v in pairs(t) do r[k]=v end return r end

local function createProxy(device)
  local pdevice,id
  local name = device.name
  local typ = device.type
  local properties = copy(device.properties or {})
  local quickVars = properties.quickAppVariables
  local interfaces = device.interfaces
  name = "TProxy "..name
  local d,_ = api.get("/devices?name="..EM.escapeURI(name))
  if d and #d>0 then
    table.sort(d,function(a,b) return a.id >= b.id end)
    pdevice = d[1]
    LOG.sys("Proxy: '%s' found, ID:%s",name,pdevice.id)
    if pdevice.type ~= typ then
      LOG.sys("Proxy: Type changed from '%s' to %s",typ,pdevice.type)
      api.delete("/devices/"..pdevice.id)
    else id = pdevice.id end
  end
  local code = {}
  code[#code+1] = [[
  local function urlencode (str)
  return str and string.gsub(str ,"([^% w])",function(c) return string.format("%%% 02X",string.byte(c))  end)
end
local function POST2IDE(path,payload)
    url = "http://"..IP..path
    net.HTTPClient():request(url,{options={method='POST',data=json.encode(payload)}})
end
local IGNORE={updateView=true,setVariable=true,updateProperty=true,MEMORYWATCH=true,APIPOST=true,APIPUT=true,APIGET=true} -- Rewrite!!!!
function QuickApp:actionHandler(action)
      if IGNORE[action.actionName] then
        return self:callAction(action.actionName, table.unpack(action.args))
      end
      POST2IDE("/TQAE/action/"..self.id,action)
end
function QuickApp:UIHandler(UIEvent) POST2IDE("/TQAE/ui/"..self.id,UIEvent) end
function QuickApp:CREATECHILD(id) self.childDevices[id]=QuickAppChild({id=id}) end
function QuickApp:APIGET(url) api.get(url) end
function QuickApp:APIPOST(url,data) api.post(url,data) end -- to get around some access restrictions
function QuickApp:APIPUT(url,data) api.put(url,data) end
]]
  code[#code+1]= "function QuickApp:onInit()"
  code[#code+1]= " self:debug('"..name.."',' deviceId:',self.id)"
  code[#code+1]= " IP = self:getVariable('PROXYIP')"
  code[#code+1]= " function QuickApp:initChildDevices() end"
  code[#code+1]= "end"

  code = table.concat(code,"\n")

  LOG.sys(id and "Proxy: Reusing QuickApp proxy" or "Proxy: Creating new proxy")

  table.insert(quickVars,{name="PROXYIP", value = EM.IPAddress..":"..EM.PORT})
  return createQuickApp{id=id,name=name,type=typ,code=code,initialProperties=properties,initialInterfaces=interfaces}
end

local function makeInitialProperties(UI,vars,height)
  local ip = {}
  vars = vars or {}
  EM.UI.transformUI(UI)
  ip.viewLayout = EM.UI.mkViewLayout(UI,height)
  ip.uiCallbacks = EM.UI.uiStruct2uiCallbacks(UI)
  ip.apiVersion = "1.2"
  local varList = {}
  for n,v in pairs(vars) do varList[#varList+1]={name=n,value=v} end
  ip.quickAppVariables = varList
  ip.typeTemplateInitialized=true
  return ip
end

function createQuickApp(args)
  local d = {} -- Our device
  d.name = args.name or "QuickApp"
  d.type = args.type or "com.fibaro.binarySensor"
  local files = args.code or ""
  local UI = args.UI or {}
  local variables = args.initialProperties.quickAppVariabels or {}
  local dryRun = args.dryrun or false
  d.apiVersion = "1.2"
  if not args.initialProperties then
    d.initialProperties = makeInitialProperties(UI,variables,args.height)
  else
    d.initialProperties = args.initialProperties
  end
  d.initialInterfaces =  args.initialInterfaces 
  if d.initialProperties.uiCallbacks and not d.initialProperties.uiCallbacks[1] then
    d.initialProperties.uiCallbacks = nil
  end
  d.initialProperties.apiVersion = "1.2"

  if type(files)=='string' then files = {{name='main',type='lua',isMain=true,isOpen=false,content=files}} end
  d.files  = {}

  for _,f in ipairs(files) do f.isOpen=false; d.files[#d.files+1]=f end

  if dryRun then return d end

  local what,d1,res="updated"
  if args.id and api.get("/devices/"..args.id) then
    d1,res = api.put("/devices/"..args.id,{
        properties={
          quickAppVariables = d.initialProperties.quickAppVariables,
          viewLayout= d.initialProperties.viewLayout,
          uiCallbacks = d.initialProperties.uiCallbacks,
        }
      })
    if res <= 201 then
      local _,_ = updateHC3QAFiles(files,args.id)
    end
  else
    --print(json.encode(d))
    d.initialProperties.deviceControlType=nil
    d1,res = api.post("/quickApp/",d)
    what = "created"
  end

  if type(res)=='string' or res > 201 then
    LOG.error("Proxy: D:%s,RES:%s",json.encode(d1),json.encode(res))
    return nil
  else
    LOG.sys("Proxy: Device %s %s",d1.id or "",what)
    return d1
  end
end

function updateHC3QAFiles(newFiles,id)
  local oldFiles = api.get("/quickApp/"..id.."/files")
  local oldFilesMap = {}
  local updateFiles,createFiles = {},{}
  for _,f in ipairs(oldFiles) do oldFilesMap[f.name]=f end
  for _,f in ipairs(newFiles) do
    if oldFilesMap[f.name] then
      updateFiles[#updateFiles+1]=f
      oldFilesMap[f.name] = nil
    else createFiles[#createFiles+1]=f end
  end
  local _,res = api.put("/quickApp/"..id.."/files",updateFiles)  -- Update existing files
  if res > 201 then return nil,res end
  for _,f in ipairs(createFiles) do
    _,res = api.post("/quickApp/"..id.."/files",f)
    if res > 201 then return nil,res end
  end
  for _,f in pairs(oldFilesMap) do
    _,res = api.delete("/quickApp/"..id.."/files/"..f.name)
    if res > 201 then return nil,res end
  end
  return newFiles,200
end

local function post2Proxy(id,path,data)
  if Devices[id].dev.parentId then id = Devices[id].dev.parentId end
  return HC3Request("POST","/devices/"..id.."/action/APIPOST",
    {args={path,data}})
end

local proxyPinger = nil
local function startProxyPinger()
  if proxyPinger then return end --only start once
  api.post("/globalVariables",{ name=EM.EMURUNNING,value=""  },'remote')
  local tick=0
  proxyPinger = os.setTimer2(function()
      api.put("/globalVariables/"..EM.EMURUNNING,{value=tostring(tick)..":"..hc3.IPaddress..":"..hc3.webPort},'remote')
      tick  = tick+1
    end,EM.EMURUNNING_INTERVAL,true)
end

local function injectProxy(id)
  local code = [[
do
   local actionH,UIh,patched = nil,nil,false
   local function urlencode (str)
     return str and string.gsub(str ,"([^% w])",function(c) return string.format("%%% 02X",string.byte(c))  end)
   end
   local IGNORE={updateView=true,setVariable=true,updateProperty=true,MEMORYWATCH=true,PROXY=true,APIPOST=true,APIPUT=true,APIGET=true} -- Rewrite!!!!
   local function enable(ip)
     if patched==false then
        actionH,UIh = quickApp.actionHandler,quickApp.UIHandler
        local function POST2IDE(path,payload)
          url = "http://"..ip..path
          net.HTTPClient():request(url,{options={method='POST',data=json.encode(payload)}})
        end
        function quickApp:actionHandler(action)
           if IGNORE[action.actionName] then
             return quickApp:callAction(action.actionName, table.unpack(action.args))
           end
           POST2IDE("/TQAE/action/"..self.id,action)
        end
        function quickApp:UIHandler(UIEvent) POST2IDE("/TQAE/ui/"..self.id,UIEvent) end
        quickApp:debug("Events intercepted by emulator at "..ip)
      end
      patched=true
   end

   local function disable()
    if patched==true then
      if actionH then quickApp.actionHandler = actionH end
      if UIh then quickApp.UIHandler = UIh end
      actionH,UIh=nil,nil
      quickApp:debug("Events restored from emulator")
      patched=false
    end
   end
   
   setInterval(function()
    local stat,res = pcall(function()
    local var,err = __fibaro_get_global_variable("HC3Emulator")
    if var then
      local modified = var.modified
      local ip = var.value
      --print(modified,os.time()-5,modified-os.time()+5)
      if modified > os.time()-5 then enable(ip:match(":(.*)"))
      else disable() end
    end
   end)
   if not stat then print(res) end
   end,3000)
end
]]
  local dev = api.get("/devices/"..id,'remote')
  assert(dev,"No such device "..id)
  if not api.get("/quickApp/"..id.."/files/PROXY",'remote') then
    api.post("/quickApp/"..id.."/files",{
        name="PROXY",
        isMain=false,
        isOpen=false,
        content=code,
        type='lua'
      },'remote')
  end
  return dev
end

EM.createProxy = createProxy
EM.post2Proxy = post2Proxy