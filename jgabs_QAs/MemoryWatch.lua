-- luacheck: globals ignore QuickApp quickApp fibaro
-- luacheck: globals ignore api net setTimeout setInterval clearInterval json
-- luacheck: globals ignore utils hc3_emulator FILES

local _=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
}

--%%name="MemoryWatch"
--%%type="com.fibaro.deviceController"
--%%u1={button='hook', text='Add memory hook', onReleased='installHooks'}
--%%u2={button='unhook', text='Remove memory hook', onReleased='removeHooks'}
--%%u3={{button='dump', text='Dump values mem', onReleased='dumpValuesMem'},{button='dump', text='Dump values cpu', onReleased='dumpValuesCPU'}}
--%%u4={{button='s60', text='60s', onReleased='sample'},{button='s300', text='5min', onReleased='sample'},{button='s1800', text='30min', onReleased='sample'},{button='s3600', text='1hour', onReleased='sample'},{button='s86400', text='24hour', onReleased='sample'}}
--%%u5={label='Total', text=''}
--%%u6={label='MaxMem', text=''}
--%%u7={label='MinMem', text=''}
--%%u8={label='MaxCPU', text=''}
--%%u9={label='MinCPU', text=''}
--%%u10={{label='MinCPU', text='YYYY'},{button='MinCPU', text='Hupp',onReleased='foo'}}

--FILE:lib/fibaroExtra.lua,fibaroExtra;

----------- Code -----------------------------------------------------------
_version = "0.3"

------------ main program ------------------
local member = fibaro.utils.member
local QAs = {}

local interval = 60*1000
local hookFile = "MEMORYWATCH"
local hookCode = [[
local  c0,t0 = os.clock(),os.time()
function QuickApp:MEMORYWATCH(id)
  collectgarbage("collect")
  local kb = collectgarbage("count")
  local  c1,t1=os.clock(),os.time()
  local cpp = (c1-c0)/(t1-t0)
  c0,t0=c1,t1
  fibaro.call(id,"MEMORYCOLLECT",self.id,kb,cpp)
end
]]

local function isChild(d) return member('quickAppChild',d.interfaces) end

local function getQAs()
  for _,d in ipairs(api.get("/devices?interface=quickApp") or {}) do
    if fibaro.getFile(d.id,hookFile) then QAs[d.id]={-1,0} end
  end
end

function QuickApp:installHooks()
  QAs = {}
  for _,d in ipairs(api.get("/devices?interface=quickApp") or {}) do
    if d.id ~= quickApp.id and (not isChild(d)) then 
      if not fibaro.getFile(d.id,hookFile) then
        fibaro.createFile(d.id,hookFile,hookCode)
        self:debugf("Installed hook in ID:%s",d.id)
      end
      QAs[d.id]={-1,0}
    end
  end
  QAs[quickApp.id]=nil
end

function QuickApp:removeHooks()
  for _,d in ipairs(api.get("/devices?interface=quickApp") or {}) do
    if d.id ~= quickApp.id and fibaro.getFile(d.id,hookFile) then 
      fibaro.deleteFile(d.id,hookFile)
      self:debugf("Removed hook from ID:%s",d.id)
    end
  end
  QAs = {}
end

local  function dumpValues(mem)
  local v,i = {},mem and 2 or 3
  for  id,data in pairs(QAs) do v[#v+1]={id,data[1],data[2]} end
  table.sort(v,function(a,b) return a[i]>b[i] end)
  for _,e in ipairs(v) do
    if e[2] >=  0 then 
      if mem then
        quickApp:debugf("%.2fkb - %s:%s (cpu:%.3f%%)",e[2],fibaro.getName(e[1]),e[1],100*e[3])
      else
        quickApp:debugf("cpu:%.3f%% - %s:%s (mem:%.2f)",100*e[3],fibaro.getName(e[1]),e[1],e[2])
      end
    end
  end
end

function QuickApp:dumpValuesMem() dumpValues(true) end
function QuickApp:dumpValuesCPU() dumpValues(false) end

local function stats()
  local maxMemID,minMemID,total,minMem,maxMem = 0,0,0,math.maxinteger,math.mininteger 
  local maxCPUID,minCPUID,minCPU,maxCPU = 0,0,math.maxinteger,math.mininteger 
  for id,data in pairs(QAs) do
    local kb,cpu = data[1],data[2]
    if kb >= 0 then
      total = total + kb
      if kb < minMem then minMemID,minMem=id,kb end
      if kb > maxMem then maxMemID,maxMem=id,kb end
      if cpu < minCPU then minCPUID,minCPU=id,cpu end
      if cpu > maxCPU then maxCPUID,maxCPU=id,cpu end
    end
  end
  if maxMemID > 0 then
    quickApp:setView("Total mem","text","Total %.2fkb",total)
    quickApp:setView("MaxMem","text","Max mem %s:%s, %.2fkb",fibaro.getName(maxMemID),maxMemID,maxMem)
    quickApp:setView("MinMem","text","Min mem %s:%s, %.2fkb",fibaro.getName(minMemID),minMemID,minMem)
    quickApp:setView("MaxCPU","text","Max cpu %s:%s, %.3f%%",fibaro.getName(maxCPUID),maxCPUID,maxCPU)
    quickApp:setView("MinCPU","text","Min cpu %s:%s, %.3f%%",fibaro.getName(minCPUID),minCPUID,minCPU)
  end
end

function QuickApp:MEMORYCOLLECT(id,kb,cpu)
  QAs[id]={kb,cpu}
end

function QuickApp:onInit()
  self:debug(self.name,self.id,_version)
  fibaro.debugFlags.onaction=false
  setTimeout(getQAs,0)
  setInterval(function()
      stats()
      for id,_ in pairs(QAs) do
        fibaro.call(id,"MEMORYWATCH",self.id)
      end
      stats()
    end,interval)
end