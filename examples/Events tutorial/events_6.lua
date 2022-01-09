--[[
If we add some time functions to our event toolbox it becomes even more useful.
--]]
local function midnight() local t = os.date("*t"); t.hour,t.min,t.sec = 0,0,0; return os.time(t) end

local function hm2sec(hmstr)
  local offs,sun
  sun,offs = hmstr:match("^(%a+)([+-]?%d*)")
  if sun and (sun == 'sunset' or sun == 'sunrise') then
    hmstr,offs = fibaro.getValue(1,sun.."Hour"), tonumber(offs) or 0
  end
  local sg,h,m,s = hmstr:match("^(%-?)(%d+):(%d+):?(%d*)")
  assert(h and m,"Bad hm2sec string "..tostring(hmstr))
  return (sg == '-' and -1 or 1)*(tonumber(h)*3600+tonumber(m)*60+(tonumber(s) or 0)+(tonumber(offs or 0))*60)
end

local function toTime(time)
    if type(time) == 'number' then return time end
    local p = time:sub(1,2)
    if p == '+/' then return hm2sec(time:sub(3))+os.time()
    elseif p == 'n/' then
      local t1,t2 = midnight()+hm2sec(time:sub(3)),os.time()
      return t1 > t2 and t1 or t1+24*60*60
    elseif p == 't/' then return  hm2sec(time:sub(3))+midnight()
    else return hm2sec(time) end
end
 
--[[
midnight() returns the time of the last midnight - subtracted from the current time we get how many seconds we are into the current day.
hm2sec() returns a time in string format to the number of seconds. ex. "00:01" is 60. It also supports that we specify the time as "sunset" or "sunset+10" where the 10 is minutes. If we add hm2sec("15:40")+midnight() we get the absolute time in second (epoch) the way that os.time() return time.
toTime() allow us to prefix the time with "+/", "t/","n/" to get epoch time as plus current time, today, or next matching time.
Ex.
toTime("10:00")     -> 10*3600+0*60 secs
toTime("10:00:05")  -> 10*3600+0*60+5*1 secs
toTime("t/10:00")    -> (t)oday at 10:00. midnight+10*3600+0*60 secs
toTime("n/10:00")    -> (n)ext time. today at 10.00AM if called before (or at) 10.00AM else 10:00AM next day
toTime("+/10:00")    -> Plus time. os.time() + 10 hours
toTime("+/00:01:22") -> Plus time. os.time() + 1min and 22sec
toTime("sunset")     -> todays sunset in relative secs since midnight, E.g. sunset="05:10", =>toTime("05:10")
toTime("sunrise")    -> todays sunrise
toTime("sunset+10")  -> todays sunset + 10min. E.g. sunset="05:10", =>toTime("05:10")+10*60
toTime("sunrise-5")  -> todays sunrise - 5min
toTime("t/sunset+10")-> (t)oday at sunset in 'absolute' time. E.g. midnight+toTime("sunset+10")
 
We can then use this to enhance our post function.
--]]
function post(event, time)
  local now = os.time()
  time = toTime(time or 0)
  if time < 0 then return elseif time < now then time = time+now end
  return setTimeout(function() handleEvent(event) end,1000*(time-now))
end

--[[
We can still do 
post({type='myEvent'},100)
to post an event with a delay of 100 seconds. But we can also do
post({type='myEvent'},"t/sunset+10")
to post the event 10 minutes after sunset today. Or we can do
post({type='myEvent'},"t/15:00")
to post at 15:00 today.
 
post({type='myEvent'},"n/15:00")
to post at 15:00 today if we post before 15:00. If we post after 15:00 it will be delayed to 15:00 the next day. This is a useful prefix for doing daily loops. We will see that in the 'schedule' event in the next example.
 
 
This way we have the basic for a small task scheduler.
--]]

local tasks = {
  Monday = {
    {"sunrise-10","morning"},
    {"18:10","outsideLight","on"},
    {"23:00","night"},
    {"sunrise-60","outsideLight","off"}
  },
  Tuesday = {
    {"sunrise-20","morning"},
    {"23:00","night"},
  },
  Wednesday = {
    {"sunrise-10","morning"},
    {"23:00","night"},
  },
  Thursday = {
    {"sunrise-10","morning"},
    {"23:00","night"},
  },
  Friday = {
    {"sunrise","morning"},
    {"24:00","night"},
  },
  Saturday = {
    {"09:00","morning"},
    {"24:00","night"},
  },
  Sunday = {
    {"09:00","morning"},
    {"23:00","night"},
  },
}

function EVENT.morning(event) -- Do stuff that should be done in the morning
  fibaro.call(77,"turnOn")
end

function EVENT.evening(event)   -- Do stuff that should be done in the evening
  fibaro.call(88,"turnOn")
end

function EVENT.night(event)   -- Do stuff that should be done in when night
  fibaro.call(88,"turnOff")
end

function EVENT.outsideLight(event) -- Control outside light...
  if event.value=='on' then
    fibaro.call(99,"turnOn")
  elseif event.value=='on' then
    fibaro.call(99,"turnOff")
  end
end

function EVENT.schedule(event)
  local day = os.date("%A")
  local dayTasks = tasks[day]
  for _,e in ipairs(dayTasks) do
    quickApp:debug("Scheduling",e[2],"for",e[1])
    post({type='log',event=e[2]},"t/"..e[1])  -- log today's events when they run
    post({type=e[2],value=e[3]},"t/"..e[1])   -- schedule today's events
  end
  post({type='schedule'},"n/00:00") -- and do it again next midnight
end

function EVENT.log(event)
  quickApp:debug("Running",event.event)
end

function QuickApp:onInit()
  post({type='schedule'})
end

--[[
We define events for day actions, like morning, lunch, watering the flavours, going to bed etc. 
and then we have a 'schedule' event that run every midnight and post the events at the time we have defined for the upcoming day.
This scheduler can of course be more advanced with more types of events. We could have 2 morning events; 'morningWorkday' and 'morningFreeday, and in the morningWorkday event handler we could check a global variable if it's vacation and then instead post an immediate {type='morningFreeday'} event to handle the day as a free day. etc etc.
--]]