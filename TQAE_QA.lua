_ = loadfile and loadfile("TQAE.lua") {
  debug = { color = true, --[[dark=true--]] }
}

--%%name="Test QA"
--%%u1 = {label='l1', text='HELLO'}
--%%proxy=true

function QuickApp:turnOn()
  self:updateProperty("value", true)
end

function QuickApp:onInit()

  self:debug(self.name, self.id)
  self:debug([[This is a simple QA that does nothing besides logging "PING"]])
  setInterval(function() self:debug("PING") end, 1000)
  setTimeout(function() self:updateView('l1','text','GOODBYE') end,10*1000)
end
