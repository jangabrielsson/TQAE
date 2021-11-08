_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
  copas=true,
}

--%%name="Updater"
--%%type="com.fibaro.deviceController"
-- %%proxy=true
--%%u1={label='info', text='...'}
--%%u2={{button='PrevU', text='<< Updates', onReleased='PrevU'},{button='Refresh', text='Refresh', onReleased='Refresh'},{button='NextU', text='Updates >>', onReleased='NextU'}}
--%%u3={label='update', text="..."}
--%%u4={label='updateDescr', text=""}
--%%u5={{button='PrevQ', text='<< QA', onReleased='PrevQ'},{button='NextQ', text='QA >>', onReleased='NextQ'}}
--%%u6={label='qa', text="..."}
--%%u7={{button='Update', text='Update', onReleased='Update'},{button='New', text='New', onReleased='New'}}
--%%u8={label='log', text="..."}

--FILE:Libs/fibaroExtra.lua,fibaroExtra;

local Date = "---"
local url = "https://raw.githubusercontent.com/jangabrielsson/TQAE/master/jgabs_QAs/Updater/MANIFEST.json"
local intercepturl = "https://raw.githubusercontent.com/jangabrielsson/TQAE/master/(.*)"

if hc3_emulator then 
  hc3_emulator.installQA{id=88,file='Examples/example2_v1.lua'}
  hc3_emulator.registerURL("GET",intercepturl,
    function(match,args)
      local file = hc3_emulator.io.open(match[1])
      local content = file:read("*all")
      file:close()
      return content,200
    end)
end

local serial = "UPD8987578996853"
local version = 1.1
local QAs={}
local manifest = {}
local updates,updP = {},0
local qaList,qaP = {},0
local fmt = string.format

local function setVersion(model,serial,version)
  local m = model..":"..serial.."/"..version
  if __fibaro_get_device_property(quickApp.id,'model') ~= m then
    quickApp:updateProperty('model',m) 
  end
end

local function isUpdatable(qa)
  local m = qa.properties.model or ""
  local s,v = m:match(":UPD(%w+)/([%w%.]+)")
  if s then return {serial=s, version=tonumber(v), name = qa.name, id = qa.id} 
  elseif m=="Toolboxuser" and qa.name:match("[Rr]unner") then
    return {serial="896661234567892", version=0.5, name = qa.name, id = qa.id}
  end
end

local function logf(...) quickApp:setView("log","text",...) quickApp:debugf(...) end
local function errorf(...) quickApp:setView("log","text",...) quickApp:errorf(...) end
local function copy(t)
  if type(t) == 'table' then
    local r = {}; for k,v in pairs(t) do r[k]=copy(v) end
    return r
  end
  return t
end

local function resolve(str,vars)
  for v,sub in pairs(vars) do str=str:gsub("%$"..v,sub) end
  return str
end

local function process(data)
  manifest = data.updates
  Date = data.date
  for id,data in pairs(manifest) do
    local name,versions,typ = data.name,data.versions,data.type
    logf("Update[%s]=%s",id,name)
    local vars = data.vars or {}
    for _,v in ipairs(versions) do
      local descr = fmt("'%s', version:%s",name,v.version)
      local vars,ref = copy(vars)
      if v.ref then
        for _,vr in ipairs(updates) do
          if vr.serial == id and vr.version == v.ref then ref=vr break end
        end
        if not ref then errorf("Ref %s for %s not found",v.ref,id) return end
        for k,d in pairs(ref.data) do if not v[k] then v[k]=d end end
      end
      for k,v in pairs(v.vars or {}) do vars[k]=v end
      local data = v
      local qas = {}
      for q,d in pairs(QAs) do if id == d.serial then qas[#qas+1]=d end end
      for n,u in pairs(data.files) do data.files[n]=resolve(u,vars) end
      for n,u in pairs(data.keep) do data.keep[n]=resolve(u,vars) end
      updates[#updates+1]={name=name, serial=id, type=typ, descr=descr, data=data, version=v.version, QAs=qas}
    end
  end
  updP = 0; quickApp:NextU()
end

local function updateInfo()
  quickApp:setView("info","text","QA Updater, v:%s, (%s)",version,Date)
  if updP > 0 then
    quickApp:setView("update","text","%s",updates[updP].descr)
    quickApp:setView("updateDescr","text","%s",updates[updP].data.descr or "")
    if qaP > 0 then
      local q = qaList[qaP]
      quickApp:setView("qa","text","ID:%s, '%s', v:%s",q.id,q.name,q.version)
      local uv,txt = updates[updP].version,"Upgrade"
      if uv == q.version then txt="Reinstall" elseif uv < q.version then txt="Downgrade" end
      quickApp:setView("Update","text",txt)
    else
      quickApp:setView("Update","text","...")
      quickApp:setView("qa","text","...")
    end
  else 
    quickApp:setView("update","text","...")
    quickApp:setView("qa","text","...")
  end
  quickApp:setView("log","text","...")
end

function QuickApp:Refresh()
  logf("Refreshing...")
  local qas = api.get("/devices?interface=quickApp")
  QAs = {}
  for _,qa in ipairs(qas or {}) do 
    QAs[qa.id]=isUpdatable(qa) 
    if QAs[qa.id] then logf("Updatable QA:%s - '%s'",qa.id,qa.name) end
  end
  net.HTTPClient():request(url,{
      options = {method = 'GET', checkCertificate = false, timeout=20000},
      success = function(res) 
        if res.status == 200 then 
          local stat,data = pcall(json.decode,res.data)
          if stat then process(data) else errorf(data) process({}) end
        else errorf("%s fetching %s",res.status,url) process({}) end
      end,
      error  = function(res) 
        errorf("%s fetching %s",res,url) process({})
      end
    })
end

function QuickApp:PrevU()
  logf("Prev U")
  if #updates > 0 then
    updP = updP-1; if updP < 1 then updP = #updates end
    qaList = updates[updP].QAs
    qaP = #qaList > 0 and 1 or 0
  end
  updateInfo()
end

function QuickApp:NextU()
  logf("Next U")
  if #updates > 0 then
    updP = updP+1; if updP > #updates then updP = 1 end
    qaList = updates[updP].QAs
    qaP = #qaList > 0 and 1 or 0
  end
  updateInfo()
end

function QuickApp:PrevQ()
  logf("Prev QA")
  if #qaList > 0 then
    qaP = qaP-1; if qaP < 1 then qaP = #qaList end
  end
  updateInfo()
end

function QuickApp:NextQ()
  logf("Next QA")
  if #qaList > 0 then
    qaP = qaP+1; if qaP > #qaList then qaP = 1 end
  end
  updateInfo()
end

local function fetchFiles(fs,n,cont)
  if n > #fs then return cont(fs) end
  local f = fs[n]
  net.HTTPClient():request(f.url,{
      success=function(resp)
        f.content = resp.data
        fetchFiles(fs,n+1,cont)
      end,
      error=function(err)
        errorf("%s, trying to fetch %s",err,f.url)
      end,
    })
end

function QuickApp:Update(ev)
  logf(ev.elementName)
  if not(qaP > 0 and #qaList > 0) then return end
  local upd = updates[updP]
  local data = upd.data
  local qa = qaList[qaP]
  local action = "upgraded"
  if upd.version == qa.version then action="reinstalled" elseif upd.version < qa.version then action = "downgraded" end
  local fs,keeps,files = {},{},data.files or {}
  for _,k in ipairs(data.keep or {}) do keeps[k]=true end
  local device = api.get("/devices/"..qa.id)
  if not device then errorf("No such QA:%s",qa.id) return end
  local deviceFiles = api.get("/quickApp/"..qa.id.."/files")
  for n,u in pairs(files or {}) do fs[#fs+1]={name=n, url=u} end
  fetchFiles(fs,1,function()
      for _,f in ipairs(deviceFiles) do -- delete old files unless keep
        if not keeps[f.name] then
          api.delete("/quickApp/"..qa.id.."/files/"..f.name)
          logf("Deleting file %s",f.name)
        end
      end
      for _,f in ipairs(fs) do
        if not keeps[f.name] then
          local fd = {isMain=false,type='lua',isOpen=false,name=f.name,content=f.content}
          local _,code = api.post("/quickApp/"..qa.id.."/files",fd)
          if code > 204 then 
            errorf("Failed creating file '%s' for QA:%s",f.name,qa.id) 
          else
            logf("Writing file %s",f.name)
          end
        end
      end
      if data.viewLayout and data.uiCallbacks then
        if type(data.viewLayout) == 'string' then data.viewLayout = json.decode(data.viewLayout) end
        if type(data.uiCallbacks) == 'string' then data.uiCallbacks = json.decode(data.uiCallbacks) end
        api.put("/devices/"..qa.id,{ properties = { viewLayout=data.viewLayout, uiCallbacks=data.uiCallbacks }})
      end
      -- Set interfaces
      -- Set quickAppVariables
      plugin.restart(qa.id)
      logf("QuickApp %s",action)
    end)
end

function QuickApp:New()
  logf("New QA")
  local upd = updates[updP]
  local data = upd.data
  local fs = {}
  for n,u in pairs(data.files or {}) do fs[#fs+1]={name=n,url=u} end
  fetchFiles(fs,1,function()
      local files = {}
      for _,f in ipairs(fs) do
        files[#files+1] = {isMain=false,type='lua',isOpen=false,name=f.name,content=f.content}
        if f.name=='main' then files[#files].isMain=true end
      end
      if type(data.viewLayout) == 'string' then data.viewLayout = json.decode(data.viewLayout) end
      if type(data.uiCallbacks) == 'string' then data.uiCallbacks = json.decode(data.uiCallbacks) end
      local fqa = {
        name = upd.name,
        type = upd.type,
        apiVersion="1.2",
        initialInterfaces = data.interfaces,
        initialProperties = {
          apiVersion="1.2",
          viewLayout=data.viewLayout,
          uiCallbacks = data.uiCallbacks,
          quickAppVariables = data.quickAppVariables,
          typeTemplateInitialized=true,
        },
        files = files
      }
      local dev,res = api.post("/quickApp/",fqa)
      if not dev then 
        errorf("Failed uploading .fqa: %s",res) 
      else
        logf("Created QuickApp '%s', deviceId:%s",dev.name,dev.id)
      end
    end)
end
----------- Code -----------------------------------------------------------
function QuickApp:onInit()
  setTimeout(function()
      self:debugf("%s, deviceId:%s",self.name ,self.id)
      --setVersion("Updater",serial,version)
      fibaro.enableSourceTriggers('deviceEvent')

      self:event({type='deviceEvent', value='removed'},function(env) 
          if QAs[env.event.id] then logf("Deleted QA:%s",env.event.id) end
          QAs[env.event.id]=nil
        end)

      self:event({type='deviceEvent', value='created'},function(env)
          local qa = api.get("/devices/"..env.event.id)
          QAs[env.event.id]=isUpdatable(qa)
          if QAs[env.event.id] then logf("Created QA:%s",env.event.id) end
        end)

      self:event({type='deviceEvent', value='modified'},function(env) 
          local qa = api.get("/devices/"..env.event.id)
          QAs[env.event.id]=isUpdatable(qa)
          if QAs[env.event.id] then logf("Modified QA:%s",env.event.id) end
        end)

      self:Refresh()
    end,0)
end
