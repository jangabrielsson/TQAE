_=loadfile and loadfile("TQAE.lua"){
  user="admin", 
  pwd="admin", 
  host="192.168.1.57",
  refreshStates = true,
  debug = { refreshStates=true },
  temp = "temp/",
  startTime="12/24/2024-07:00",
}

--FILE:lib/fibaroExtra.lua,fibaroExtra;

--%%name="Test FibaroExtra"
--%%type="com.fibaro.sprinkler"
--%%quickVars = {['x'] = 17, ['y'] = 42 }
--%%proxy=true

function QuickApp:onInit()
  self:debugf("Name:%s, ID:%s",self.name,self.id)

  fibaro.enableSourceTriggers('ClimateZone') -- Listen to ClimateZone triggers

  self:event({type='ClimateZone', propertyName='active'},
    function(env)
      local e = env.event
      self:debugf("ClimateZone %s is set to %s", e.id, e.newValue and "active" or "inactive")
    end)

end