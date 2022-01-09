--[[
The way to  get away from nested setTimeout's and make flatten it out using an event model. I keep preaching the use of an event style for programming on the HC2/HC3 but I haven't seen anyone catching on. It's the only way to keep your logic and program structure together when programming in a highly asynchronous world. Home automation with sensors that can send signals at any time tends to be very asynchronous - things can happen in any order at any time and you still need your programming logic to make sense and not become a chaos of special cases  that needs to be dealt with...
 
In your example you fire 4 timers to play songs with almost the identical code (except for the song) - that should trigger an "coding alarm" asking for a better way to do it - which you did....
 
So, how do we do "event programming"? Well we can make it advanced or really easy - let's start really  easy.
 
The basic concept is that you still set a timer, but instead of running a function, the timer posts an event. An event is just a piece of data that is associated with a handler (Lua function) that is executed whenever the event is posted.

This gives a flavour of  the style - the code is all about posting events (with optional delays) and defining handlers for these events.  You get structure and reuse. The beauty is that it scales to handle HC3 device triggers, asynchronous http requests and also handling multiple events in parallel....
In the case above, if you could detect the player finished playing the song and then  post the endSong event it  would make it neat....
--]]

------------ Event utilities ----------
local EVENT = {}
function post(event, time) return setTimeout(function() handleEvent(event) end,1000*(time or 0)) end

function handleEvent(event)
   local handler = EVENT[event.type]
   handler(event)
end
--------------------------- Our code ------------------
function EVENT.playSong(event)
        currentTime = os.date("%H:%M")
        songName = MusicPathPi..jMT[event.id].Title..MusicPathEnd
        songTime = tonumber(jMT[event.id].Length)
        print(os.date(),songName,songTime)
        songVolume = event.volume
        quickApp:playErev(songName,songVolume)
        post({type='endSong',cont=event.cont},songTime) --  post ending event and pass on ev. continuation  event
end

function EVENT.endSong(event)  post(event.cont) end --  Post continuation event (that will play next  song)

function EVENT.playList(event)  -- Play first song in list, and add  continuation event to  play next song
     local list = event.list
     if #list>0 then
       local song = table.remove(list,1)
      post({type='playSong',id=song.id,volume=song.volume, cont={type='playList',list=list}})
    end
end

post({type='playList', list={{id=1,volume=10},{id=8,volume=8},{id=4,volume=15}}})