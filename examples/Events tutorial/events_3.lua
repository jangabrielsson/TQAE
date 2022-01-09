--[[
To stop playing the queue we need to do some modification to our event code.
We need to add a 'stopList' event that we can post to stop playing and we need to add a cancel(timer) command to our event toolbox so that we can cancel a posted event. 
In our event handlers when we post an event we save the reference to that post (post() returns a reference to the setTimeout timer we started). In our case we save it in a variable 'lastTimer'. So when we want to stop the playing of the list we can check if lastTimer ~= nil and assume that we are playing a list. We then stop the actual paying (I guessed there was a quickApp:stopErev() command) and then we cancel the posted event that lastTimer refer to.
--]]
------------ Event toolbox ----------
local EVENT = {}
function post(event, time) return setTimeout(function() handleEvent(event) end,1000*(time or 0)) end
-- Add command to stop an outstanding post. post() returns timer reference.
function cancel(timer) if timer then clearTimeout(timer) end end

function handleEvent(event)
   local handler = EVENT[event.type]
   handler(event)
end
--------------------------- Our code ------------------
local lastTimer = nil
function EVENT.playSong(event)
        currentTime = os.date("%H:%M")
        songName = MusicPathPi..jMT[event.id].Title..MusicPathEnd
        songTime = tonumber(jMT[event.id].Length)
        print(os.date(),songName,songTime)
        songVolume = event.volume
        quickApp:playErev(songName,songVolume)
        lastTimer=post({type='endSong',cont=event.cont},songTime) --  post ending event and pass on ev. continuation  event
end

function EVENT.endSong(event)  lastTimer=post(event.cont) end --  Post continuation event (that will play next  song)

function EVENT.playList(event)  -- Play first song in list, and add  continuation event to  play next song
     local list = event.list
     if #list>0 then
       local song = table.remove(list,1)
      lastTimer=post({type='playSong',id=song.id,volume=song.volume, cont={type='playList',list=list}})
    else lastTimer=nil end
end

function EVENT.stopList(event)
   if lastTimer then               -- If we are playing
      lastTimer=cancel(lastTimer)  -- ...cancel any outstanding event post
      quickApp:stopErev()          -- I don't know the command to stop the player...
   end
end

post({type='playList', list={{id=1,volume=10},{id=8,volume=8},{id=4,volume=15}}}) -- start playing
post({type='stopList'}) -- Stop playing song

--[[
There is another neat advantage with the event model. Each step we take in our application logic is a posted event -> handled event. And each posted event is calling the event handler with a setTimeout call. Every time we do a setTImeout we give the opportunity to other code in our QA to run.
For the QA to receive button and slider clicks from the UI there need to be time for them to execute. If you run a busy loop
--]]
while true
   fibaro.sleep(1000)
end
--[[
Your QA will not get any UI actions. Other QAs can not be able to call your QA with fibaro.call(your_QA_id,<action>, ...) either.. (they can call but your code will not respond).
So by "chunking up" our code into "blocks" chained together by posting events we will automatically give time to other systems and get a more responsive QA.
The post function will do a setTimeout(handler,0) if we don't specify a time for the post command. 0 says that we want to run the handler as soon as possible. However, if there are other functions in the queue waiting to run they will be given a chance to run first (ex. there may be a UI click that waiting to call your button function).
 
It may also be that you want to give time to your own code... because you may be running 2 or more "event chains in parallell:
--]]
function EVENT.ping(event)
    quickApp:debug("PING from",event.user)
    post({type='ping',user=event.user,delay=event.delay}, event.delay)  -- Call pong with the data we got in the event
end

function EVENT.pong(event)
    quickApp:debug("PONG from",event.user)
    post({type='pong',user=event.user,delay=event.delay}, event.delay) -- Call ping with the data we got in the event
end

post({type='ping',user='Bob',delay=3000})
post({type='ping',user='Ann',delay=2000})
--[[
Here we start 2 ping "ping-pong event chains". Bob and Ann, each pinging and ponging with different intervals (3s and 2s) - running in "parallell".
The ping event handler just carries out the job the event specifies (logging ping and user) and then it post an event to the other handler with the data and the delay specified in the event.
 
We can of course easily do this with just two setTimeout loops but the code structure easily becomes messy - here we abstract the logic (the handlers) from the processes driving the logic.
 
 --]]
