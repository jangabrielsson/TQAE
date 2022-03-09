_=loadfile and loadfile("TQAE.lua"){
  --refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true, mqtt=true },
--offline = true,
}

--[[
NodeRed server (node-red-contrib-aedes) that answers to the messages.
--]]

--%%name="MMQTT"
--%%type="com.fibaro.binarySwitch"

function QuickApp:onInit()
  self:debug(self.name,self.id)
  local function handleConnect(event)
    self:debug("connected: "..json.encode(event))
    self.client:subscribe("test/#")
    self.client:publish("test/blah", "test".. os.time())
  end
  self.client = mqtt.Client.connect('192.168.1.50', {clientId="HC3"})
  self.client._debug = true
  self.client:addEventListener('published', function(event) self:debug("published: "..json.encode(event)) end)  
  self.client:addEventListener('message', function(event) self:debug("message: "..json.encode(event)) end)
  self.client:addEventListener('connected', handleConnect)
end