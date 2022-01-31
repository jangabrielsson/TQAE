_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, UIEevent=true },
}

--%%name="StateQA"
--%%type="com.fibaro.multiPositionSwitch"

function QuickApp:updatePositions(positions)
  self.positions = positions
  self:updateProperty("availablePositions", positions)
end

function QuickApp:getPosition() return fibaro.getValue(self.id,"position") end

function QuickApp:setPosition(elm)
  if self.positions[elm] then
    self:updateProperty('position',elm)
  else self:warning("Undefined position:",elm) end
end

function QuickApp:onInit()
  self:debug(self.name," ",self.id)
end