_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
}

--%%name="CrashNotifier"
--%%type="com.fibaro.binarySwitch"
--%%u1={button='enable', text='Push errors - enable', onReleased='enableClicked'}
--%%u2={label='label1', text=''}
--%%u3={label='label2', text=''}
--%%u4={label='label3', text=''}

--FILE:lib/fibaroExtra.lua,fibaroExtra;

----------- Code -----------------------------------------------------------
_version = "0.3"

------------ main program ------------------
local fmt = string.format
local enabled = false
local messages = {"","",""}
local ID = 0

function QuickApp:enableClicked(_) 
  enabled=not enabled
  self:setView("enable","text","Push errors - %s",enabled and "enabled" or "disabled")
  self:updateProperty("value", enabled)
end

function QuickApp:turnOn() enabled=false;  self:enableClicked() end
function QuickApp:turnOff() enabled=true; self:enableClicked() end

function QuickApp:main()
  self:event({type='deviceEvent', value='crashed'},function(event)
      self:debug("Event:"..json.encode(event))
      table.insert(messages,1,fmt("%s, ID:%s, %s",os.date("%a %b %d %X"),event.id,event.error))
      table.remove(messages,4)
      for i=1,#messages do self:updateView("label"..i,"text",messages[i]) end
      if enabled then fibaro.call(ID,"sendPush",messages[1]) end
    end)
end

function QuickApp:onInit()
  self:debug(self.name,self.id)
  ID = tonumber(self:getVariable("pushID")) or 0
  self:enableClicked()
end