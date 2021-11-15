--luacheck: globals ignore hc3_emulator
--luacheck: globals ignore QuickApp QuickAppChild quickApp fibaro json __TAG net api class plugin
--luacheck: globals ignore __fibaro_get_device __fibaro_get_device_property
--luacheck: globals ignore setTimeout clearTimeout setInterval clearInterval
--luacheck: ignore 212/self
--luacheck: ignore 432/self

_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true, refreshStates=true },
  copas=true,
}

--%%name="QAUpdater"
--%%type="com.fibaro.deviceController"
-- %%proxy=true
--%%u1={label='info', text='...'}
--%%u2={{button='PrevU', text='<< Updates', onReleased='BTN'},{button='Refresh', text='Refresh', onReleased='BTN'},{button='NextU', text='Updates >>', onReleased='BTN'}}
--%%u3={label='update', text="..."}
--%%u4={{button='PrevV', text='<< Version', onReleased='BTN'},{button='Install', text='Install', onReleased='BTN'},{button='NextV', text='Version >>', onReleased='BTN'}}
--%%u5={label='version', text="..."}
--%%u6={{button='PrevQ', text='<< QA', onReleased='BTN'},{button='Update', text='Update', onReleased='BTN'},{button='NextQ', text='QA >>', onReleased='BTN'}}
--%%u7={label='qa', text="..."}
--%%u8={label='log', text="..."}

--FILE:lib/fibaroExtra.lua,fibaroExtra;

local btnHandlers,Date = "---"
local url = "https://raw.githubusercontent.com/jangabrielsson/TQAE/master/jgabs_QAs/Updater/MANIFEST.json"
local intercepturl = "https://raw.githubusercontent.com/jangabrielsson/TQAE/master/(.*)"

if hc3_emulator then 
  hc3_emulator.installQA{id=88,file='examples/example2_v1.lua'}
  hc3_emulator.registerURL("GET",intercepturl,
    function(match,args)
      local file = hc3_emulator.io.open(match[1])
      local content = file:read("*all")
      file:close()
      return content,200
    end)
end

local SERIAL = "UPD896661234567894"
local VERSION = 0.6
local QAs={}
local manifest = {}
local updates,udpP = {},0
local veP = 0
local qaP = 0
local fmt = string.format

function QuickApp:BTN(ev) btnHandlers[ev.elementName](ev) end -- Avoid (too) global handlers

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
  elseif m=="ToolboxUser" then
    if qa.name:match("[Rr]unner") and not qa.name:match("Proxy")  then
      return {serial="896661234567892", version=0.5, name = qa.name, id = qa.id}
    elseif qa.name:match("[Cc]hildren") and qa.name:match("[Hh]ue")  then
      return {serial="896661234567893", version=1.19, name = qa.name, id = qa.id}
    end
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

local lastData -- cache
local function process(data)
  if data then lastData = data else data = lastData end
  if not data then return end
  manifest = data.updates
  Date = data.date
  updates={}
  for id,data in pairs(manifest) do
    local name,typ,descr,noUpgrade = data.name,data.type,data.noUpgrade,data.descr
    logf("Update[%s]=%s",id,name)
    local vars = data.vars or {}
    local update = { name=name, serial=id, descr=fmt("%s %s",name, descr and "- "..descr or ""), typ=typ, noUpgrade=noUpgrade }
    local versions = {}
    for _,v in ipairs(data.versions or {}) do
      local version = {}
      version.descr = fmt("v:%s %s",v.version,v.descr or "")
      local vars,ref = copy(vars)
      if v.ref then
        for _,vr in ipairs(versions) do
          if vr.serial == id and vr.version == v.ref then ref=vr break end
        end
        if not ref then errorf("Ref %s for %s not found",v.ref,id) return end
        for k,d in pairs(ref.data) do if not v[k] then v[k]=d end end
      end
      for k,val in pairs(v.vars or {}) do vars[k]=val end
      local qas,files,keep = {},copy(v.files),copy(v.keep)
      for q,d in pairs(QAs) do if id == d.serial then qas[#qas+1]=d end end
      for n,u in pairs(files) do files[n]=resolve(u,vars) end
      for n,u in pairs(keep) do keep[n]=resolve(u,vars) end
      version.version = v.version
      version.QAs = qas
      version.files = files
      version.keep = keep
      version.data = v
      versions[#versions+1]=version
    end
    update.versions = versions
    updates[#updates+1]=update
  end
  updP = 0; btnHandlers.NextU()
end

local function updateInfo()
  quickApp:setView("info","text","QA Updater, v:%s, (%s)",VERSION,Date)
  quickApp:setView("update","text","...")
  quickApp:setView("version","text","...")
  quickApp:setView("qa","text","...")
  quickApp:setView("log","text","...")
  if updP > 0 then
    local upd = updates[updP]
    quickApp:setView("update","text","%s",upd.descr)
    if veP > 0 then
      local version = upd.versions[veP]
      quickApp:setView("version","text","%s",version.descr)
      if qaP > 0 then
        local qa = version.QAs[qaP]
        quickApp:setView("qa","text","ID:%s, '%s', v:%s",qa.id,qa.name,qa.version)
        local uv,txt = version.version,"Upgrade"
        if uv == qa.version then txt="Reinstall" elseif uv < qa.version then txt="Downgrade" end
        quickApp:setView("Update","text",txt)
      end
    end
  end
end

local function Refresh()
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

local function PrevU()
--  logf("Prev U")
  if #updates > 0 then
    updP = updP-1; if updP < 1 then updP = #updates end
    veP = 0; btnHandlers.NextV()
  end
end

local function NextU()
--  logf("Next U")
  if #updates > 0 then
    updP = updP+1; if updP > #updates then updP = 1 end
    veP = 0; btnHandlers.NextV()
  end
end

local function PrevV()
--  logf("Prev V")
  local versions = updates[udpP] and updates[udpP].versions or {}
  if #versions > 0 then
    veP = veP-1; if veP < 1 then veP = #versions end
    qaP = 0; btnHandlers.NextQ()
  end
end

local function NextV()
--  logf("Next V")
  local versions = updates[udpP] and updates[udpP].versions or {}
  if #versions > 0 then
    veP = veP+1; if veP > #versions then veP = 1 end
    qaP = 0; btnHandlers.NextQ()
  end
end

local function PrevQ()
--  logf("Prev QA")
  local qaList = updates[udpP] and updates[udpP].versions and updates[udpP].versions[veP] or {}
  qaList = qaList.QAs or {}
  if #qaList > 0 then
    qaP = qaP-1; if qaP < 1 then qaP = #qaList end
  end
  updateInfo()
end

local function NextQ()
--  logf("Next QA")
  local qaList = updates[updP] and updates[updP].versions and updates[updP].versions[veP] or {}
  qaList = qaList.QAs or {}
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
        if resp.status > 204 then errorf("%s, trying to fetch %s",resp.data,f.url)
        else 
          f.content = resp.data
          fetchFiles(fs,n+1,cont)
        end
      end,
      error=function(err)
        errorf("%s, trying to fetch %s",err,f.url)
      end,
    })
end

local function Update(ev)
  logf(ev.elementName)
  local upd      = updates[updP]  or {}
  local versions = upd.versions   or {}
  local version  = versions[veP]  or {}
  local qaList   = version.QAs    or {}
  local qa       = qaList[qaP]
  if not qa then return end

  local data = version.data

  if upd.noUpgrade then logf("Can't be updated, please create New") return end

  local action = "upgraded"
  if version.version == qa.version then action="reinstalled" elseif version.version < qa.version then action = "downgraded" end
  local fs,keeps,files = {},{},version.files or {}
  for _,k in ipairs(version.keep or {}) do keeps[k]=true end
  local device = api.get("/devices/"..qa.id)
  if not device then errorf("No such QA:%s",qa.id) return end
  local deviceFiles = api.get("/quickApp/"..qa.id.."/files")
  for n,u in pairs(files or {}) do fs[#fs+1]={name=n, url=u} end
  fetchFiles(fs,1,function()
      local existMap,filesAltered = {},{}
      local stat,_ = pcall(function()
          for _,f in ipairs(deviceFiles) do -- delete files not in new QA
            existMap[f.name]=f
            if not files[f.name] and not keeps[f.name] then
              filesAltered[#filesAltered+1]={'deleted',f}
              local _,code = api.delete("/quickApp/"..qa.id.."/files/"..f.name)
              if code > 204 then 
                errorf("Failed deleting file '%s' for QA:%s",f.name,qa.id) 
                error("deleting")
              end
              logf("Deleting file %s",f.name)
            end
          end
          local updates,updNames = {},{}
          for _,f in ipairs(fs) do
            if not keeps[f.name] then
              local fd = {isMain=f.name=='main',type='lua',isOpen=false,name=f.name,content=f.content}
              if not existMap[f.name] then
                filesAltered[#filesAltered+1]={'created',f.name}
                local _,code = api.post("/quickApp/"..qa.id.."/files",fd)
                if code > 204 then 
                  errorf("Failed creating file '%s' for QA:%s",f.name,qa.id) 
                  error("creating")
                end 
                logf("Creating file %s",f.name) 
              else
                updates[#updates+1]=fd
                updNames[#updNames+1]=f.name
              end
            end
          end
          if #updates>0 then -- Write all updates at ones - minimize restarts
            local _,code = api.put("/quickApp/"..qa.id.."/files",updates)
            local oldUs = {}
            for _,f in ipairs(updates) do
              oldUs[#oldUs+1]=existMap[f.name]
            end
            filesAltered[#filesAltered+1]={'updated',oldUs}
            if code > 204 then 
              errorf("Failed updating files %s for QA:%s",json.encode(updNames),qa.id) 
              error("update")
            end
            logf("Updating files %s",json.encode(updNames)) 
          end
          if data.viewLayout and data.uiCallbacks then
            if type(data.viewLayout) == 'string' then data.viewLayout = json.decode(data.viewLayout) end
            if type(data.uiCallbacks) == 'string' then data.uiCallbacks = json.decode(data.uiCallbacks) end
            api.put("/devices/"..qa.id,{ properties = { viewLayout=data.viewLayout, uiCallbacks=data.uiCallbacks }})
          end
          if data.quickAppVariables then
            local oldVars,oldVarsMap,newVarsMap = __fibaro_get_device_property(qa.id,"quickAppVariables"),{},{}
            for n,v in ipairs(oldVars)  do oldVarsMap[n]=v end
            for n,v in ipairs(data.quickAppVariables)  do newVarsMap[n]=v end
            for n,v in pairs(newVarsMap) do
              if not oldVarsMap[n] then 
                oldVars[#oldVars+1]={name=n,value=v}
              end
            end
            api.post("/plugins/updateProperty", {deviceId=qa.id, propertyName="quickAppVariables", value=oldVars})
          end
          data.interfaces = data.interfaces or { "quickApp" }
          api.post("/devices/addInterface",{devicesId={qa.id},interfaces=data.interfaces})
          plugin.restart(qa.id)
          logf("QuickApp %s",action)
        end)
      if not stat then
        errorf("Failed updating QA:%s - trying to restore",qa.id)
        for _,f in ipairs(filesAltered) do
          if f[1]=='deleted' then
            api.post("/quickApp/"..qa.id.."/files",f[2])
          elseif f[1]=='created' then
            api.delete("/quickApp/"..qa.id.."/files/"..f[2])
          elseif f[1]=='updated' then
            api.put("/quickApp/"..qa.id.."/files",f[2])
          end
        end
      end
    end)
end

local function Install()
  logf("New QA")
  local upd      = updates[updP]  or {}
  local versions = upd.versions   or {}
  local version  = versions[veP]  or {}
  local qaList   = version.QAs    or {}
  local qa       = qaList[qaP]
  if not qa then return end

  local data = version.data

  local fs = {}
  for n,u in pairs(version.files or {}) do fs[#fs+1]={name=n,url=u} end
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
        type = upd.typ,
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

btnHandlers = { 
  PrevU=PrevU, Refresh=Refresh, NextU=NextU, 
  PrevV=PrevV, Install=Install, NextV=NextV, 
  PrevQ=PrevQ, Update=Update, NextQ=NextQ,
}

function QuickApp:updateMe(id)
  local qa = QAs[id]
  if not qa then self:warning("Update requested from non-updateble QA") return end
  for _,upd in pairs(updates) do
    ----
  end
end

----------- Code -----------------------------------------------------------
function QuickApp:onInit()
  setVersion("Updater",SERIAL,VERSION)
  setTimeout(function()
      self:debugf("%s, deviceId:%s",self.name ,self.id)
      --setVersion("Updater",serial,version)
      fibaro.enableSourceTriggers('deviceEvent')

      self:event({type='deviceEvent', value='removed'},function(env) 
          if QAs[env.event.id] then logf("Deleted QA:%s",env.event.id) process() end
          QAs[env.event.id]=nil

        end)

      self:event({type='deviceEvent', value='created'},function(env)
          local qa = api.get("/devices/"..env.event.id)
          QAs[env.event.id]=isUpdatable(qa)
          if QAs[env.event.id] then logf("Created QA:%s",env.event.id) process() end
        end)

      self:event({type='deviceEvent', value='modified'},function(env) 
          local qa = api.get("/devices/"..env.event.id)
          QAs[env.event.id]=isUpdatable(qa)
          if QAs[env.event.id] then logf("Modified QA:%s",env.event.id) process() end
        end)

      Refresh()
    end,0)
end
