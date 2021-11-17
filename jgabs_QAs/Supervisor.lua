if dofile and not hc3_emulator then
  hc3_emulator = {
    name = "Superevisor",    -- Name of QA
    poll = 2000,             -- Poll HC3 for triggers every 2000ms
    --offline = true,
  }
  dofile("fibaroapiHC3.lua")
end--hc3

--FILE:lib/fibaroExtra.lua,fibaroExtra;

local SERIAL = "UPD896661234567894"
local VERSION = 0.63

local QAs = {}

class 'Watcher'()
function Watcher:__init(id)
  QAs[id]=self
  self.id = id
  self:resetTimer()
end

function Watcher:resetTimer()
  if self._timer then clearTimeout(self._timer) self._timer=nil end
  self._timer = setTimeout(function() self:timesUp() end,TIMEOUT)
end

function Watcher:heartBeat() self:resetTimer() end

function Watcher:remove() 
  if self._timer then clearTimeout(self._timer) self._timer=nil end
  QAs[self.id]=nil
end

function QuickApp:onInit()
  self:debug(self.name, self.id)
  self:setVersion("Supervisor",SERIAL,VERSION)

  self:subscribe({type='HEARTBEAT'},
    function(ev)
      if QAs[ev.id] then 
        QAs[ev.id]:heartBeat()
      else 
        Watcher(id) 
      end
    end)

  self:event({type='deviceEvent', value='removed'},function(env) 
      if QAs[env.event.id] then 
        logf("Deleted QA:%s",env.event.id)
        QAs[env.event.id]:delete()
      end
    end)
end

