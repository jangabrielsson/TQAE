--[[
An event is just a pice of data that we can post. We then define "event handlers", functions that react (or trigger) on specific events.
In the example above they are not "stored" anywhere.  We post 'playList' events and we have an event handler that triggers on any 'playList' being posted.
 
Inside the HC3, any change (ex. devices changing states or globals being set) generates an internal event. We can see them in the "History panel". Some of these events are "transformed" to triggers and are used to trigger scenes that have specified conditions for specific triggers. In scenes, we also get the triggers as a Lua table in the variable 'sourceTrigger'
Ex. if sensor 88 is breached, the sourceTrigger we get looks like

{type='device', id=88, property='value', value=true, oldValue=false}

In QAs we unfortunately don't get these sourceTriggers. What we can do is to fetch the raw events with the /refreshStates api and then create our own "event mechanism" in our QA.
In my fibaroExtra.lua library I do this. I listen to the /refreshStates api, get events, transform them into "sourceTrigger format" and "post" them using a similar mechanism as in my example above. The main difference is that the definition of event handlers is more advanced and allows matching the whole event instead of just using the type of the event as a selection mechanism. 
 
But the cool thing is that I code in the same style even if it is my own "invented" event type like 'playList' in the example above, or if I define an event handler for a sensor getting breached. 
This is the way it looks using the fibaroExtra.lua library
--]]

function QuickApp:onInit()
    self:event({type='device', id=88, property='value', value=true},
        function(env) 
              self:debug("Sensor breached, turning in lamp")
              fibaro.call(99,"turnOn")
       end)
end

--[[
This is a trivial handler that will react if sensor 88 is breached and call the handler function that logs a message and turns on device 99.
I can define any number of these handlers and my event library hides all the complexity for me. It is also very efficient in matching events to handler, allowing several hundreds of event handlers to be defined without causing a lot of processing overhead.
 
An advantage if this style of programming is also that if I want to debug my code and fake that the sensor is triggered I can just post the event myself.
--]]
post({type='device', id=88, property='value', value=true})

--[[
and my previously defined event handler will trigger the same way as if the real device was breached. 
 --]]