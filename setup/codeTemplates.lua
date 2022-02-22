local version = "1.0"
local code = {
  ['Scene template'] =
[[_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { traceFibaro=true },
--offline = true,
}

--%%name="My Scene"
--%%scene=true
-- %%runAtStart=true
--%%noterminate=true

CONDITIONS = {  -- example condition triggering on device 37 becoming 'true'
  conditions = { {
      id = 37,
      isTrigger = true,
      operator = "==",
      property = "value",
      type = "device",
      value = true
      } },
  operator = "all"
}

function ACTION()()
  local hc = fibaro
  jT = json.decode(hc.getGlobalVariable("HomeTable")) 
  -- Your code
end

]],
  ['QA template'] = 
[[_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
}

--%%name="My QA"
--%%type="com.fibaro.binarySwitch"

function QuickApp:onInit()
  self:debug(self.name, self.id)
end

]],
  ['QA template with fibaroExtra'] = 
[[_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
}

--%%name="My QA"
--%%type="com.fibaro.deviceController"
-- %%proxy=true

--FILE:lib/fibaroExtra.lua,fibaroExtra;

----------- Code -----------------------------------------------------------
function QuickApp:onInit()
  self:debugf("%s, deviceId:%s",self.name ,self.id)
end
]],

  ['MultilevelSwitch'] =
[[_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
}

--%%name="MyMultilevelSwitch"
--%%type="com.fibaro.multilevelSwitch"
--%%u1={label='info', text=''}
--%%u2={{button='turnOn', text='Turn On',  onReleased='turnOn'},{button='turnOff', text='Turn Off',  onReleased='turnOff'}}
--%%u3={slider='val', min=0, max=99, onChanged='slider'}

function QuickApp:turnOn()
  self:updateProperty("value",99)
  self:info()
end

function QuickApp:turnOff()
  self:updateProperty("value",0)
  self:info()
end

function QuickApp:slider(ev) self:setValue(ev.values[1]) end

function QuickApp:setValue(value)
  self:updateProperty("value",value)
  self:info()
end

function QuickApp:info()
  local val = fibaro.getValue(self.id,"value")
  self:updateView("info","text","Value is "..val)
  self:updateView("val","value",tostring(val))
end

function QuickApp:onInit()
  self:debug(self.name, self.id)
  self:info()
end]]
}
return {version = version, templates = code}