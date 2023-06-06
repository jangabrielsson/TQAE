_=loadfile and loadfile("TQAE.lua"){
  debug = { color = false }
}

--%%name="Test QA"

function QuickApp:turnOn()
  self:updateProperty("value",true)
end

local function printc(code,str)
  print(string.format('\u{001b}[%dm%s\u{001b}[0m',code,str))
end

function QuickApp:onInit()
  self:debug(self.name,self.id)
  self:debug([[This is a simple QA that does nothing besides logging "PING"]])
  printc(32,"Hello")
  setInterval(function() self:debug("PING") end,1000)
end 
