--[[
  local test = Global("myTest",true)
  test.value=77
  print(test.value)
  test:notifier(function(val,var) self:debugf("Value for %s changed to %s",tostring(var),val) end)
--]]
class "Global"
function Global:__init(name,create,value)
  __assert_type(name, "string")
  if create then
    api.post("/globalVariables/",{name=name,value=json.encode(value or "")})
  end
  assert(api.get("/globalVariables/"..name),"Global variable "..name.." doesn't exist")
  self._name=name
  self._value = fibaro.getGlobalVariable(name)
  local function castGlobal(str)
    local map={['true']={true},['false']={false}}
    if str == nil or str == "nil" then return nil
    elseif map[str] then return map[str][1]                         -- Constants?
    elseif str:match("^[%{%[]") then return (json.decode(str)) end  -- Looks like a json table?
    return tonumber(str) or str                                     -- Looks like a number
  end
  fibaro.event({type='global-variable',name=name},
    function(env)
      self._value = castGlobal(env.event.value)
      if self._notifier then self._notifier(self._value,self) end
    end)
  self.value = property(
    function(self)       -- getter
      return self._value
    end,        
    function(self,value) -- setter
      self._value = value
      if value == nil then value = "nil" end
      fibaro.setGlobalVariable(name,(json.encode(value)))
    end 
  )
end
function Global:notifier(fun) self._notifier = fun end
function Global:__tostring() return "Global:"..self._name end

--[[
local d = Device(77)
d:turnOn()
d:setValue(88)
d.value = 99
local value = d.value
print(d)
d:notifier('prop',function(val,prop,dev) print("Device changed ",prop," to ",val) end)
--]]
class "Device"
function Device:__init(id)
  __assert_type(id, "number")
  local d = __fibaro_get_device(id)
  assert(id,"No such deviceId:"..id)
  self._propTypes = {}
  self._notifiers = {}
  --if d.interfaces:member('quickApp') then addQuickAppMethods(self,id) end
  for prop,v in pairs(d.properties) do
    local propk = "_"..prop
    self[propk] = v
    self._propTypes[prop]=type(v)
    self[prop] = property(
      function(self)       -- getter
        return self[propk]
      end,        
      function(self,value) -- setter
        __assert_type(value, self._propTypes[prop])
        self[propk] = value
        api.post("/plugins/updateProperty", {deviceId=id, propertyName=prop, value=value})
      end 
    )
    fibaro.event({type='device',id=id,property=prop},function(env) 
        self[propk]=env.event.value
        if self._notifiers[prop] then self._notifiers[prop](env.event.value,prop,self) end
      end)
  end
  for action,n in pairs(d.actions) do
    self[action] = function(_,...)
      assert(#{...}==n,"Wrong number of arguments to "..action)
      return self:call(action,...)
    end
  end
end
function Device:call(action,...) return fibaro.call(id,action,...) end
function Device:notifier(prop,fun) self._notifiers[prop] = fun end
function Device:__tostring() return "Device:"..self._id end

--[[
self.vars=QuickVars(self)
self.vars.x = 9          -- Set quickAppVariable 'x'
print(self.vars.x)       -- Access quickAppVariable 'x'
self.vars:create('y',77) -- Create quickAppVariable 'y'
print(self.vars.y)       -- Access quickAppVariable 'y'
--]]
class 'QuickVars'
function QuickVars:create(name,value,noupd)       
  self.vals[name]=value
  self[name]=property(
    function(_) return self.vals[name] end,
    function(_,val) self.vals[name]=val; self.qa:setVariable(name,val) end
  )
  if not noupd then fibaro.setVariable(name,value) end
end
function QuickVars:__init(qa)
  self.vals,self.qa = {},qa
  for _,v in ipairs(qa.properties.quickAppVariables or {}) do self:create(v.name,v.value,true) end
end