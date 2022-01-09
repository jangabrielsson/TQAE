--[[
So the previous example controls a light with a set of sensors. Example in a room.
Assume that we want to generalise this to handle all sensor and lights in a house. We then need to set up a table which sensor controls which lights. What we do here is that we setup what sensor control what room, and then a table with rooms and their lights.
--]]

local rooms = {  -- Lights in rooms and delays
   kitchen =    {devices = { 77, 99, 11}, delay=50*60}},
   bedroom =    {devices = { 76, 54},     delay=40*60}},
   hall =       {devices = { 87, 32},     delay =10*60}},
}

local sensors = {  -- Which room a sensor controls
    101 = 'kitchen',
    108 = 'kitchen',
    113 = 'bedroom',
    111 = 'bedroom',
    199 = 'hall',
    155 = 'hall',
    144 = 'hall',
}

function EVENT.breached(event)
    local room = sensors[event.id]           -- Get room the sensor control
    room = rooms[room]
    room.timer = cancel(room.timer)          -- Cancel eventual turnOff event already posted
    post({type='turnOn',room=room})          -- Turn on lights
end

function EVENT.safe(event)
    local room = sensors[event.id]           -- Get room the sensor control
    room = rooms[room]
    room.timer = cancel(room.timer)          -- Cancel eventual turnOff event already posted
    timer = post({type='turnOff',room=room},room.delay) -- Post turnOff event after delay - (in effect restart countdown)
end

function EVENT.turnOn(event) fibaro.call(event.room.devices,"turnOn") end
function EVENT.turnOff(event) event.room.timer=nil; fibaro.call(event.room.devices,"turnOff") end

-- Check our sensors every second and generate events if they have changed value
local sensorValues = {}
setInterval(function()
   for id,_ in ipairs(sensors) do
       local value = fibaro.getValues(id,'value')
       if sensorValues[id]~=value then
          sensorValues[id]=value
          post({type=value and 'breached' or 'safe',id=id})
       end
  end
end,1000)

--[[
The main logic from the previous example is still there - the difference is that instead of working with individual lights we work with rooms. We turn on/off rooms, and rooms contains light IDs, delays, and eventual timer.
--]]