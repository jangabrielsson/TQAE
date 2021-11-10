--%%name="Example2"

local serial = "UPD895136589346853"
local version = 2.0

function QuickApp:setVersion(model,serial,version)
  local m = model..":"..serial.."/"..version
  if __fibaro_get_device_property(self.id,'model') ~= m then
    self:updateProperty('model',m) 
  end
end

function QuickApp:onInit()
  self:debug(self.name,self.id,version)
  self:setVersion("QA",serial,version)
end