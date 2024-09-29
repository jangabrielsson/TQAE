_MODULES = _MODULES or {} -- Global
_MODULES.cron={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,format = fibaro.debugFlags,string.format
    local function dateTest(dateStr0)
      local days = {sun=1,mon=2,tue=3,wed=4,thu=5,fri=6,sat=7}
      local months = {jan=1,feb=2,mar=3,apr=4,may=5,jun=6,jul=7,aug=8,sep=9,oct=10,nov=11,dec=12}
      local last,month = {31,28,31,30,31,30,31,31,30,31,30,31},nil

      local function seq2map(seq) local s = {} for _,v in ipairs(seq) do s[v] = true end return s; end

      local function flatten(seq,res) -- flattens a table of tables
        res = res or {}
        if type(seq) == 'table' then for _,v1 in ipairs(seq) do flatten(v1,res) end else res[#res+1] = seq end
        return res
      end

      local function _assert(test,msg,...) if not test then error(format(msg,...),3) end end

      local function expandDate(w1,md)
        local function resolve(id)
          local res
          if id == 'last' then month = md res=last[md] 
          elseif id == 'lastw' then month = md res=last[md]-6 
          else res= type(id) == 'number' and id or days[id] or months[id] or tonumber(id) end
          _assert(res,"Bad date specifier '%s'",id) return res
        end
        local step = 1
        local w,m = w1[1],w1[2]
        local start,stop = w:match("(%w+)%p(%w+)")
        if (start == nil) then return resolve(w) end
        start,stop = resolve(start), resolve(stop)
        local res,res2 = {},{}
        if w:find("/") then
          if not w:find("-") then -- 10/2
            step=stop; stop = m.max
          else step=(w:match("/(%d+)")) end
        end
        step = tonumber(step)
        _assert(start>=m.min and start<=m.max and stop>=m.min and stop<=m.max,"illegal date intervall")
        while (start ~= stop) do -- 10-2
          res[#res+1] = start
          start = start+1; if start>m.max then start=m.min end  
        end
        res[#res+1] = stop
        if step > 1 then for i=1,#res,step do res2[#res2+1]=res[i] end; res=res2 end
        return res
      end

      local function parseDateStr(dateStr) --,last)
        local map = table.map
        local seq = string.split(dateStr," ")   -- min,hour,day,month,wday
        local lim = {{min=0,max=59},{min=0,max=23},{min=1,max=31},{min=1,max=12},{min=1,max=7},{min=2000,max=3000}}
        for i=1,6 do if seq[i]=='*' or seq[i]==nil then seq[i]=tostring(lim[i].min).."-"..lim[i].max end end
        seq = map(function(w) return string.split(w,",") end, seq)   -- split sequences "3,4"
        local month0 = os.date("*t",os.time()).month
        seq = map(function(t) local m = table.remove(lim,1);
            return flatten(map(function (g) return expandDate({g,m},month0) end, t))
          end, seq) -- expand intervalls "3-5"
        return map(seq2map,seq)
      end
      local sun,offs,day,sunPatch = dateStr0:match("^(sun%a+) ([%+%-]?%d+)")
      if sun then
        sun = sun.."Hour"
        dateStr0=dateStr0:gsub("sun%a+ [%+%-]?%d+","0 0")
        sunPatch=function(dateSeq)
          local h,m = (fibaro.getValue(1,sun)):match("(%d%d):(%d%d)")
          dateSeq[1]={[(tonumber(h)*60+tonumber(m)+tonumber(offs))%60]=true}
          dateSeq[2]={[math.floor((tonumber(h)*60+tonumber(m)+tonumber(offs))/60)]=true}
        end
      end
      local dateSeq = parseDateStr(dateStr0)
      return function() -- Pretty efficient way of testing dates...
        local t = os.date("*t",os.time())
        if month and month~=t.month then dateSeq=parseDateStr(dateStr0) end -- Recalculate 'last' every month
        if sunPatch and (month and month~=t.month or day~=t.day) then sunPatch(dateSeq) day=t.day end -- Recalculate sunset/sunrise
        return
        dateSeq[1][t.min] and    -- min     0-59
        dateSeq[2][t.hour] and   -- hour    0-23
        dateSeq[3][t.day] and    -- day     1-31
        dateSeq[4][t.month] and  -- month   1-12
        dateSeq[5][t.wday] or false      -- weekday 1-7, 1=sun, 7=sat
      end
    end

    fibaro.dateTest = dateTest

    -- Alternative, several timers share a cron loop instance.
    do
      local jobs,timer = {},nil -- {fun = {test=.., args={...}}}

      local function cronLoop()
        if timer==nil or timer.expired then
          local nxt = (os.time() // 60 + 1)*60
          local function loop()
            local stat,res
            for _,job in pairs(jobs) do
              if job.test() then
                for ref,entry in pairs(job.handlers) do
                  stat,res = pcall(entry.fun,table.unpack(entry.args))
                  if not stat then fibaro.error(__TAG,ref,res) end
                end
              end
            end
            nxt = nxt + 60
            timer['%TIMER%']=setTimeout(loop,1000*(nxt-os.time()))
          end
          timer = setTimeout(loop,1000*(nxt-os.time()))
        end
        return timer
      end

      local NJOBS = 1
      function fibaro.cron(str,fun,...)
        jobs[str] = jobs[str] or {test=dateTest(str),handlers={}}
        local entry = {fun=fun,args={...}}
        local ref = string.format("[cron:%d:%s]",NJOBS,str); NJOBS = NJOBS+1
        jobs[str].handlers[ref] = entry
        cronLoop()
        return ref
      end
      function fibaro.removeCronJob(ref)
        for str,job in pairs(jobs) do
          if job.handlers[ref] then job.handlers[ref]=nil end
          if not next(job.handlers) then jobs[str]=nil end
        end
      end
      function fibaro.cronLoop() return cronLoop() end
    end

    function fibaro.cron2(str,fun,...) 
      local test,args,timer = dateTest(str),{...},nil
      local nxt = (os.time() // 60 + 1)*60
      local function loop()
        local stat,res
        if test() then stat,res = pcall(fun,table.unpack(args)) else stat=true end
        if stat then
          nxt = nxt + 60
          timer['%TIMER%']=setTimeout(loop,1000*(nxt-os.time()))
        else fibaro.error(__TAG,res) end
      end
      timer = setTimeout(loop,1000*(nxt-os.time()))
      return timer
    end
  end
} -- Cron

