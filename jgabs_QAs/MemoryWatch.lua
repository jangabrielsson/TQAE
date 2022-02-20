_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
}

--%%name="MemoryWatch"
--%%type="com.fibaro.deviceController"
--%%u1={button='hook', text='Add memory hook', onReleased='installHooks'}
--%%u2={button='unhook', text='Remove memory hook', onReleased='removeHooks'}
--%%u3={button='dump', text='Dump values', onReleased='dumpValues'}
--%%u4={label='Total', text=''}
--%%u5={label='Max', text=''}
--%%u6={label='Min', text=''}

--FILE:lib/fibaroExtra.lua,fibaroExtra;

----------- Code -----------------------------------------------------------
_version = "0.2"

------------ main program ------------------
local fmt = string.format
local member = fibaro.utils.member
local QAs = {}

local interval = 5000
local hookFile = "MEMORYWATCH"
local hookCode = [[
function QuickApp:MEMORYWATCH(id)
  collectgarbage("collect")
  local kb = collectgarbage("count")
  fibaro.call(id,"MEMORYCOLLECT",self.id,kb)
end
]]

local function isChild(d) return member('quickAppChild',q.interfaces) end

local function getQAs()
  for _,d in ipairs(api.get("/devices?interface=quickApp") or {}) do
    if fibaro.getFile(d.id,hookFile) then QAs[d.id]=0 end
  end
end

function QuickApp:installHooks()
  QAs = {}
  for _,d in ipairs(api.get("/devices?interface=quickApp") or {}) do
    if d.id ~= quickApp.id and not isChild(d) and not fibaro.getFile(d.id,hookFile) then 
      fibaro.createFile(d.id,hookFile,hookCode)
      self:debug("Installed hook in ID:%s",d.id)
    end
    QAs[d.id]=0
  end
  QAs[quickApp.id]=nil
end

function QuickApp:removeHooks()
  for _,d in ipairs(api.get("/devices?interface=quickApp") or {}) do
    if d.id ~= quickApp.id and not isChild(d) and not fibaro.getFile(d.id,hookFile) then 
      fibaro.deleteFile(d.id,hookFile)
      self:debug("Removed hook from ID:%s",d.id)
    end
  end
  QAs = {}
end

function QuickApp:dumpValues()
  local v = {}
  for  id,kb in pairs(QAs) do v[#v+1]={id,kb} end
  table.sort(v,function(a,b) return a[2]>b[2] end)
  for _,e in ipairs(v) do
    print(fmt("%.2f - %s:%s",e[2],fibaro.getName(e[1]),e[1]))
  end
end

local function stats()
  local maxID,minID,total,min,max = 0,0,0,math.maxinteger,math.mininteger
  for id,kb in pairs(QAs) do
    total = total + kb
    if kb < min then minID,min=id,kb end
    if kb > max then maxID,max=id,kb end
  end
  if maxID > 0 then
    quickApp:setView("Total","text","Total %.2fkb",total)
    quickApp:setView("Max","text","Max %s:%s, %.2fkb",fibaro.getName(maxID),maxID,max)
    quickApp:setView("Min","text","Min %s:%s, %.2fkb",fibaro.getName(minID),minID,min)
  end
end

function QuickApp:MEMORYCOLLECT(id,kb)
  QAs[id]=kb
end

function QuickApp:onInit()
  self:debug(self.name,self.id)
  fibaro.debugFlags.onaction=false
  setTimeout(getQAs,0)
--  setInterval(function()
--      stats()
--      for id,_ in pairs(QAs) do
--        fibaro.call(id,"MEMORYWATCH",self.id)
--      end
--    end,interval)
end