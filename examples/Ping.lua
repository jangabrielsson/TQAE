_=loadfile and loadfile("TQAE.lua"){
  user="admin", 
  pwd="admin", 
  host="192.168.1.57",
  temp = "temp/",
  startTime="12/24/2024-07:00",
}

--%%name="Ping"

hc3_emulator.installQA{file='examples/Pong.lua'}
--fibaro.sleep(0)
function QuickApp:pong(ret)
  self:debug("Pong")
  setTimeout(function() fibaro.call(ret,"ping",self.id) end, 2000)
end

function QuickApp:onInit()
  print("START")
  fibaro.call(1002,"ping",self.id)
end