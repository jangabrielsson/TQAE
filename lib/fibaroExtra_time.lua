_MODULES = _MODULES or {} -- Global
_MODULES.time={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,utils,format = fibaro.debugFlags,fibaro.utils,string.format

    local function toSeconds(str)
      __assert_type(str,"string" )
      local sun = str:match("(sun%a+)") 
      if sun then return toSeconds(str:gsub(sun,fibaro.getValue(1,sun.."Hour"))) end
      local var = str:match("(%$[A-Za-z]+)") 
      if var then return toSeconds(str:gsub(var,fibaro.getGlobalVariable(var:sub(2)))) end
      local h,m,s,op,off=str:match("(%d%d):(%d%d):?(%d*)([+%-]*)([%d:]*)")
      off = off~="" and (off:find(":") and toSeconds(off) or toSeconds("00:00:"..off)) or 0
      return 3600*h+60*m+(s~="" and s or 0)+((op=='-' or op =='+-') and -1 or 1)*off
    end
    fibaro.toSeconds = toSeconds

    local function midnight() local t = os.date("*t"); t.hour,t.min,t.sec = 0,0,0; return os.time(t) end
    fibaro.midnight = midnight
    function fibaro.getWeekNumber(tm) return tonumber(os.date("%V",tm)) end
    function fibaro.now() return os.time()-midnight() end  

    function fibaro.between(start,stop,optTime)
      __assert_type(start,"string" )
      __assert_type(stop,"string" )
      start,stop,optTime=toSeconds(start),toSeconds(stop),optTime and toSeconds(optTime) or toSeconds(os.date("%H:%M"))
      stop = stop>=start and stop or stop+24*3600
      optTime = optTime>=start and optTime or optTime+24*3600
      return start <= optTime and optTime <= stop
    end
    function fibaro.time2str(t) return format("%02d:%02d:%02d",math.floor(t/3600),math.floor((t%3600)/60),t%60) end

    local function hm2sec(hmstr,ns)
      local offs,sun
      sun,offs = hmstr:match("^(%a+)([+-]?%d*)")
      if sun and (sun == 'sunset' or sun == 'sunrise') then
        if ns then
          local sunrise,sunset = fibaro.utils.sunCalc(os.time()+24*3600)
          hmstr,offs = sun=='sunrise' and sunrise or sunset, tonumber(offs) or 0
        else
          hmstr,offs = fibaro.getValue(1,sun.."Hour"), tonumber(offs) or 0
        end
      end
      local sg,h,m,s = hmstr:match("^(%-?)(%d+):(%d+):?(%d*)")
      utils.asserts(h and m,"Bad hm2sec string %s",hmstr)
      return (sg == '-' and -1 or 1)*(tonumber(h)*3600+tonumber(m)*60+(tonumber(s) or 0)+(tonumber(offs or 0))*60)
    end

-- toTime("10:00")     -> 10*3600+0*60 secs
-- toTime("10:00:05")  -> 10*3600+0*60+5*1 secs
-- toTime("t/10:00")    -> (t)oday at 10:00. midnight+10*3600+0*60 secs
-- toTime("n/10:00")    -> (n)ext time. today at 10.00AM if called before (or at) 10.00AM else 10:00AM next day
-- toTime("+/10:00")    -> Plus time. os.time() + 10 hours
-- toTime("+/00:01:22") -> Plus time. os.time() + 1min and 22sec
-- toTime("sunset")     -> todays sunset in relative secs since midnight, E.g. sunset="05:10", =>toTime("05:10")
-- toTime("sunrise")    -> todays sunrise
-- toTime("sunset+10")  -> todays sunset + 10min. E.g. sunset="05:10", =>toTime("05:10")+10*60
-- toTime("sunrise-5")  -> todays sunrise - 5min
-- toTime("t/sunset+10")-> (t)oday at sunset in 'absolute' time. E.g. midnight+toTime("sunset+10")

    local function toTime(time)
      if type(time) == 'number' then return time end
      local p = time:sub(1,2)
      if p == '+/' then return hm2sec(time:sub(3))+os.time()
      elseif p == 'n/' then
        local t1,t2 = midnight()+hm2sec(time:sub(3),true),os.time()
        return t1 > t2 and t1 or t1+24*60*60
      elseif p == 't/' then return  hm2sec(time:sub(3))+midnight()
      else return hm2sec(time) end
    end
    fibaro.toTime,fibaro.hm2sec = toTime,hm2sec

  end
} -- Time functions

