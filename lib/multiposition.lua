_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, UIEevent=true },
}

--%%name="multiPositionSwitch"
--%%type="com.fibaro.multiPositionSwitch"

local function f1(value) print(value) end

function QuickApp:updatePositions(tab)
  self.pmap = {}
  for _,v in ipairs(tab) do self.pmap[v.name]={action=v.action} v.action=nil end
  self:updateProperty("availablePositions", positions)
end

function QuickApp:getPosition() return fibaro.getValue(self.id,"position") end

function QuickApp:setPosition(value)
  if self.pmap[value or ""] then
    self.pmap[value].action(value)
    self:updateProperty('position',value)
  end
end

function QuickApp:turnOn()
  self:setPosition('A')
  self:updateProperty('value',true)
end

function QuickApp:toggle()
  if fibaro.getValue(self.id,'value') then self:turnOff()
  else self:turnOn() end
end

function QuickApp:turnOff()
  self:setPosition('D')
  self:updateProperty('value',false)
end

function QuickApp:onInit()
  self:updatePositions{
    {label = "label A", name="A", action=f1},
    {label = "label B", name="B", action=f1},
    {label = "label C", name="C", action=f1},
    {label = "label D", name="D", action=f1},
  }
  if self:getPosition()=="" then -- initialise
    self:updateProperty("position","A") -- self:setPosition('A')
  end
end