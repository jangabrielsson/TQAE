--[[
When we have the 'cancel' function in our event toolbox we can easily code the use case
"turn on light when sensor is breached and turn off light when sensor been safe for x seconds"
It can handle multiple sensors and starts the countdown for turning off the light after all sensors have turned safe.
--]]
local timer
local delay = 5*60                        -- Number of seconds all sensors need to be safe to turn off light
local light = 23                          -- DeviceID of light
local sensors = {44,56,77,88}             -- Sensors that can trigger light

function EVENT.breached(event)
     timer = cancel(timer)                -- Cancel eventual turnOff event already posted
     post({type='turnOn',id=light})       -- Turn on light
end

function EVENT.safe(event)
    timer = cancel(timer)                 -- Cancel eventual turnOff event being posted
    timer = post({type='turnOff',id=light},delay) -- Post turnOff event after delay - (in effect restart countdown)
end

function EVENT.turnOn(event) fibaro.call(event.id,"turnOn") end
function EVENT.turnOff(event) timer=nil; fibaro.call(event.id,"turnOff") end

-- Check our sensors every second and generate events if they have changed value
local sensorValues = {}
setInterval(function()
   for _,id in ipairs(sensors) do
       local value = fibaro.getValues(id,'value')
       if sensorValues[id]~=value then
          sensorValues[id]=value
          post({type=value and 'breached' or 'safe',id=id})
       end
  end
end,1000)

--[[
Here we run a second loop to poll the sensors and post their state if they have changed value - it may not be that efficient. There is a much more effective way to receive and post device changes into our program using the /refreshStates api but that requires a bit more code. But we can later change out the poll loop with the /refreshStates api logic without having to change the rest of our code....
--]]