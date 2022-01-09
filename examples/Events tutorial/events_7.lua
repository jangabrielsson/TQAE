--[[
The last enhancement to our toolbox requires a change in how we declare event handlers.
The problem today is that we can only define one handler for each event type. This is because we use the event type as a key in the EVENT table that holds our handlers - and a Lua table must have unique keys in a key-value table.
 
Now we can define 
function EVENT.device(event) -- trigger on {type='device, id=<id>, value=<value>} events
   if event.id == 88 then fibaro.call(99,"turnOn")
   elseif event.id == 89 then fibaro.call(100,"turnOn") end
end
We have one handler for 'device' events but we need to handle what device id should do what inside the handler.
 
It would be nice if we could declare one handler for id=88 and another for id=89. Like this

EVENT({type='device',id=88}, function(event) -- id 88 turns on 99
      fibaro.call(99,'turnOn')
  end)
EVENT({type='device',id=89}, function(event) -- id 89 turns on 99
      fibaro.call(99,'turnOn')
  end)
EVENT({type='device'}, function(event)       -- all other ids turn on 100
      fibaro.call(100,'turnOn')
  end)
 
The change we need to do in our event toolbox is
--]]

local events = {}
function EVENT(event, handler)
   events[event.type] = events[event.type] or {}
   local es = events[event.type]
   es[#es+1]={event=event, handler=handler}    -- register handler under the event.type key
end

function handleEvent(event)
   local es =  events[event.type]
   for _,e in pairs(es) do
     for k,v in pairs(e.event) do if event[k]~=v then break end -- find matching event
     e.handler(event)
     return
   end
end

--[[
We still register event handlers with the event type so we can quickly look up handlers for a given event type (we can make it even more efficient but this is ok for the moment). However we can have many handlers for a given type so we then check if the event matches the event we registered for a specific handler and if so call the handler.
This also means that it's important in what order we declare our event handlers and we will match them in the order they are declared and when we have a match we run that handler but don't run other matching handlers declared afterwards.
 
Note also that
EVENT({type='device'},function(event) .... end)
will match all events with the type 'device', e.g. the id can be any id. This is useful as we may want to have general handlers that can trigger on many specific events.
--]]