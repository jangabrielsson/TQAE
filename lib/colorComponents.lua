-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro
-- luacheck: globals ignore api json class setInterval clearInterval
-- luacheck: globals ignore ColorComponents

class 'ColorComponents'

function ColorComponents:__init(args)
  local function same(e1,e2)
    for k1,v1 in pairs(e1) do if e2[k1] == nil then return false end end
    for k2,_  in pairs(e2) do if e1[k2] == nil then return false end end
    return true
  end
  local parent    = args.parent
  self.parent     = parent
  self.brighness  = 0
  self.DIM_TIME   = args.dim_time or 10000
  self.DIM_MIN    = args.dim_min or 0
  self.DIM_MAX    = args.dim_max or 99
  self.DIM_INTERV = args.dim_interv or 1000
  self.DIM_STEP   = math.floor((self.DIM_MAX-self.DIM_MIN) / (self.DIM_TIME/self.DIM_INTERV) +  0.5)

  local dev = api.get("/devices/"..self.parent.id)
  if  not same(dev.properties.colorComponents or {},args.colorComponents) then -- Add/remove color components if needed
    self:debugf("Updating color components -will restart...")
    api.put("/devices/"..self.parent.id,{
        properties = { 
          colorComponents = args.colorComponents 
        }
      }
    )
  end
  self.ccComps = {}
  self.colorComponents = dev.properties.colorComponents
  self.brightness = dev.properties.value

  -- Set up functions for parent
  function parent:turnOff() self:turnOff() end
  function parent:turnOn() self:turnOn() end
  function parent:setValue(value) self:setValue(value) end
  function parent:setColor(...) self:setColor(...) end
  function parent:setColorComponents(arg) self:setColorComponents(arg) end
  function parent:stopLevelChange() self:stopLevelChange() end 
  function parent:startLevelIncrease() self:startLevelIncrease() end
  function parent:startLevelDecrease() self:startLevelDecrease() end
  function parent:startColorEnhancement(arg) self:startColorEnhancement(arg) end
  function parent:startColorFade(arg) self:startColorFade(arg) end
  function parent:stopColorChange(arg) self:stopColorChange(arg) end
end

function ColorComponents:turnOff() -- TurnOff
  if not self.parent.properties.state then return end
  local colorComponents = self.colorComponents
  self.parent:debug("Off")
  self.parent:setVariable('last',json.encode({br=self.brightness,cc=colorComponents})) -- Save when turned off so we can restore at turnOn
  self.parent:setValue(0)
  self.parent:updateProperty('state',false)     -- We use state to note if deevice is turned off
  for cc,_ in pairs(colorComponents) do
    colorComponents[cc]=0                -- Set all components to 0. Would be nice to disable controls too...
    self:stopLevel(cc)                   -- Stop ongoing dimming/fading
  end
  self:setColorComponents(colorComponents)
end

function ColorComponents:turnOn() -- TurnOn
  if self.parent.properties.state then return end
  self.parent:debug("On")
  local ll = self.parent:getVariable('last')    -- Restore values as they were when we turned off
  if type(ll)=='string' and ll ~= "" then
    ll = json.decode(ll)
    self.brightness = ll.br
    self.colorComponents = ll.cc
  end
  for cc,_ in pairs(self.colorComponents) do -- Stop ongoing dimming/fading
    self:stopLevel(cc)
  end
  self:setValue(self.brightness)
  self.parent:updateProperty('state',true)
  self:setColorComponents(self.colorComponents)
end

-- Value is type of integer (0-99)
function ColorComponents:setValue(value) -- Set brightness level
  self:debugf("setValue: %s", value)
  self.brightness = value
  self.parent:updateProperty('value',self.brightness)
end

function ColorComponents:setColor(...) -- r,g,b,ww,cw,...  ??
  local arg,colorComponents = {...},self.colorComponents
  self:debugf("setColor: %s",arg)
  if type(arg)=='table' and type(arg[1])=='number' then -- R,G,B,W is what we get from dot color picker
    colorComponents.red       = arg[1] or colorComponents.red
    colorComponents.green     = arg[2] or colorComponents.green
    colorComponents.blue      = arg[3] or colorComponents.blue
    colorComponents.warmWhite = arg[4] or colorComponents.warmWhite  -- Seems to not be "standardized"...
    colorComponents.coldWhite = arg[5] or colorComponents.coldWhite
    -- Should we allow for amber, purple etc?
  end
  self:setColorComponents(colorComponents)
end

function ColorComponents:setColorComponents(arg)   -- This is better to use than :setColor
  self:debugf("setColorComponents: %s",arg or "nil")
  local colorComponents = self.colorComponents
  for cc,_ in pairs(colorComponents) do                -- Copy over known color components
    colorComponents[cc]=arg[cc] or colorComponents[cc]
  end
  -- Update property for QA without causing restart...
  api.post("/plugins/updateProperty",{deviceId=self.parent.id,propertyName='colorComponents',value=colorComponents})
end

function ColorComponents:startInc(comp,start,stop,get,set)   -- Generic leveChange for brightness and colorComponents
  self:stopLevel(comp)
  if not self.parent.properties.state then self:turnOn() end
  self.ccComps[comp] = self.ccComps[comp] or {}
  self.ccComps[comp].ref = setInterval(function()
      self:debugf("Increase %s: %s",comp,get())
      if get() < stop then                -- We probably want to stop dimming if value changed by other operation
        set(math.min(get()+self.DIM_STEP,stop))
      else self:stopLevel(comp) end
    end,self.DIM_INTERV)
end
function ColorComponents:startDec(comp,start,stop,get,set)
  self:stopLevel(comp)
  if not self.parent.properties.state then self:turnOn() end
  self.ccComps[comp] = self.ccComps[comp] or {}
  self.ccComps[comp].ref = setInterval(function()
      self:debugf("Decrease %s: %s",comp,get())
      if get() > start then              -- We probably want to stop dimming if value changed by other operation
        set(math.max(get()-self.DIM_STEP,start)) 
      else self:stopLevel(comp) end
    end,self.DIM_INTERV)
end
function ColorComponents:stopLevel(arg)
  if self.ccComps[arg] and self.ccComps[arg].ref then 
    clearInterval(self.ccComps[arg].ref)
    self.ccComps[arg].ref = nil
  end
end

function ColorComponents:stopLevelChange() self:stopLevel('brightness') end  -- levelChange for brightness
function ColorComponents:startLevelIncrease() 
  self:startInc('brightness',0,99,
    function() return self.brightness end,
    function(val) self:setValue(val) end
  )
end
function ColorComponents:startLevelDecrease()
  self:startDec('brightness',0,99,
    function() return self.brightness end,
    function(val) self:setValue(val) end
  )
end

function ColorComponents:startColorEnhancement(arg) -- levelChange for colorComponents
  self:startInc(arg,0,99,
    function() return self.colorComponents[arg] end,
    function(val) self.colorComponents[arg]=val; self:setColorComponents(self.colorComponents) end
  )
end
function ColorComponents:startColorFade(arg) 
  self:startDec(arg,0,99,
    function() return self.colorComponents[arg] end,
    function(val) self.colorComponents[arg]=val; self:setColorComponents(self.colorComponents) end
  )
end
function ColorComponents:stopColorChange(arg) self:stopLevel(arg) end

function ColorComponents:debugf(fmt,...)
  local args = {...}
  for  i=1,#args do if type(args[i])=='table' then args[i]=json.encode(args[i])  end end
  quickApp:debug(string.format(fmt,table.unpack(args)))
end

------------------ QuickApp that is a ColorController  using  ColorComponents
--[[
function QuickApp:onInit()
  quickApp = self
  self:debug(self.id,self.name)
  self.colorComponent = ColorComponents{
    parent = self,
    colorComponents = { -- Comment out components not needed
      warmWhite =  0,
      coldWhite = 0,
      red = 0,
      green = 0,
      blue = 0,
      amber = 0,
      cyan = 0,
      purple = 0,
    },
    dim_time   = 10000,  -- Time to do a full dim cycle, max to min, min to max
    dim_min    = 0,      -- Min value
    dim_max    = 99,     -- Max value
    dim_interv = 1000    -- Interval between dim steps
  }
end
--]]