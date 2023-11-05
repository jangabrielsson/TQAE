--[[
TQAE - fibaroExtra for the Fibaro Home Center 3
Copyright (c) 2021 Jan Gabrielsson
Email: jan@gabrielsson.com
                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.
--]]


-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro QuickerAppChild class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore __assert_type __fibaro_get_device __TAG __fibaro_get_device_property
-- luacheck: globals ignore utils hc3_emulator urlencode sceneId table string _MODULES
---@diagnostic disable: cast-local-type, undefined-field, need-check-nil
fibaro,QuickApp = fibaro or {},QuickApp or {}

-------------------- Base ----------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.base={ author = "jan@gabrielsson.com", version = '0.4', depends={}, 
  init = function()
    fibaro.FIBARO_EXTRA = "v0.964"
    fibaro.debugFlags  = fibaro.debugFlags or { modules=false }
    fibaro.utils = {}
    _MODULES.base._inited=true
    local debugFlags = fibaro.debugFlags

    function fibaro.printf(fmt,...) print(string.format(fmt,...)) end
    fibaro.printf("fibaroExtra %s, ©%s",fibaro.FIBARO_EXTRA,"jan@gabrielsson.com")
    function fibaro.protectFun(fun,f,level)
      return function(...)
        local stat,res = pcall(fun,...)
        if not stat then
          res = res:gsub("fibaroExtra.lua:%d+:","").."("..f..")"
          error(res,level) 
        else return res end
      end
    end
    function fibaro.utils.asserts(cond, ...)
      if not cond then error("assertion failed!: " .. string.format(...), 2) end
    end

    local function copy(obj)
      if type(obj) == 'table' then
        local res = {} for k,v in pairs(obj) do res[k] = copy(v) end
        return res
      else return obj end
    end

    local function equal(e1,e2)
      if e1==e2 then return true
      else
        if type(e1) ~= 'table' or type(e2) ~= 'table' then return false
        else
          for k1,v1 in pairs(e1) do if e2[k1] == nil or not equal(v1,e2[k1]) then return false end end
          for k2,_  in pairs(e2) do if e1[k2] == nil then return false end end
          return true
        end
      end
    end

    if not table.maxn then 
      function table.maxn(tbl) local c=0 for _ in pairs(tbl) do c=c+1 end return c end
    end

    function table.member(k,tab) for i,v in ipairs(tab) do if equal(v,k) then return i end end return false end
    function table.map(f,l,s) s = s or 1; local r,m={},table.maxn(l) for i=s,m do r[#r+1] = f(l[i]) end return r end
    function table.mapf(f,l,s) s = s or 1; local e=true for i=s,table.maxn(l) do e = f(l[i]) end return e end
    function table.delete(k,tab) local i = table.member(tab,k); if i then table.remove(tab,i) return i end end
    table.equal,table.copy = equal,copy

    if hc3_emulator then fibaro._emulator= "TQAE" end
    if fibaro._emulator == "fibemu" then
      hc3_emulator = { EM = { EMURUNNING = "TQAE_running"}}
      hc3_emulator.create = {} -- need to do this better
      function hc3_emulator.create.globalVariables() end
      function hc3_emulator.create.binarySwitch() end
      function hc3_emulator.create.multilevelSwitch() end
      hc3_emulator.IPaddress = fibaro._IPADDRESS
      hc3_emulator.getmetatable = function(obj) return getmetatable(obj) end
    end

    local old_tostring = tostring
    fibaro._orgToString = old_tostring
    function tostring(obj)
      if type(obj)=='table' and not getmetatable(obj) then
        if obj.__tostring then return type(obj.__tostring)=='string' and obj.__tostring or obj.__tostring(obj) 
        elseif debugFlags.json then return json.encodeFast and json.encodeFast(obj) or json.encode(obj)  end
      end
      return old_tostring(obj)
    end

    local _init,_onInit = QuickApp.__init,nil

    local function initQA(selfv)
      local dev = __fibaro_get_device(selfv.id)
      if not dev.enabled then
        if fibaro.__disabled then pcall(fibaro.__disabled,selfv) end
        selfv:debug("QA ",selfv.name," disabled")
        return
      end
      for m,_ in pairs(_MODULES or {}) do fibaro.loadModule(m) end
      selfv.config = {}
      for _,v in ipairs(dev.properties.quickAppVariables or {}) do
        if v.value ~= "" then selfv.config[v.name] = v.value end
      end
      quickApp = selfv
      if _onInit then _onInit(selfv) end
    end

    function QuickApp.__init(self,...) -- We hijack the __init methods so we can control users :onInit() method
      _onInit = self.onInit
      self.onInit = initQA
      _init(self,...)
    end

    function fibaro.loadModule(name)
      local m = _MODULES[name]
      assert(m,"Module "..tostring(name).." doesn't exist")
      if not m._inited then m._inited=true
        for _,d in ipairs(m.depends) do fibaro.loadModule(d) end
        m.init()
        if fibaro.debugFlags.modules then fibaro.printf("Loaded %s, v%s, ©%s %s",name,m.version,m.author,json.encode(m.depends)) end 
      end
    end
  end
} -- Base
if not _MODULES.base._inited then _MODULES.base.init() end

-------------------- Error handling ----------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.error={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    json = json or {}
    local debugFlags,format,copy = fibaro.debugFlags,string.format,table.copy
    local setinterval,encode,decode =  setInterval, json.encode, json.decode -- gives us a better error messages
    local oldClearTimout,oldSetTimout

    if  hc3_emulator then
      setTimeout,oldSetTimout=function(f,...)
        local t
        local function nf(...)
          if type(t)=='table' and t._prehook then t._prehook() end
          return f(...) 
          --if t._posthook then t._posthook() end
        end
        t = oldSetTimout(nf,...)
        return t
      end,setTimeout
    elseif not hc3_emulator then -- Patch short-sighthed setTimeout...
      local function timer2str(t)
        return format("[Timer:%d%s %s]",t.n,t.log or "",os.date('%T %D',t.expires or 0))
      end
      local N,NC = 0,0
      local function isTimer(timer) return type(timer)=='table' and timer['%TIMER%'] end
      local function makeTimer(ref,log,exp) N=N+1 return {['%TIMER%']=(ref or 0),n=N,log=type(log)=='string' and " ("..log..")" or nil,expires=exp or 0,__tostring=timer2str} end
      local function updateTimer(timer,ref) timer['%TIMER%']=ref end
      local function getTimer(timer) return timer['%TIMER%'] end

      clearTimeout,oldClearTimout=function(ref)
        if isTimer(ref) then ref=getTimer(ref)
          oldClearTimout(ref)
        end
      end,clearTimeout
      setTimeout,oldSetTimout=function(f,ms,log)
        local ref,maxt=makeTimer(nil,log,math.floor(os.time()+ms/1000+0.5)),2147483648-1
        local fun = function() -- wrap function to get error messages
          if debugFlags.lateTimer then
            local d = os.time() - ref.expires
            if d > debugFlags.lateTimer then fibaro.warning(__TAG,format("Late timer (%ds):%s",d,tostring(ref))) end
          end
          NC = NC-1
          ref.expired = true
          if ref._prehook then ref._prehook() end -- pre and posthooks
          local stat,res = pcall(f)
          if ref._posthook then ref._posthook() end
          if not stat then 
            fibaro.error(nil,res)
          end
        end
        NC = NC+1
        if ms > maxt then -- extend timer length > 26 days...
          updateTimer(ref,oldSetTimout(function() updateTimer(ref,getTimer(setTimeout(fun,ms-maxt))) end,maxt))
        else updateTimer(ref,oldSetTimout(fun,math.floor(ms+0.5))) end
        return ref
      end,setTimeout

      function setInterval(fun,ms) -- can't manage looong intervals
        return setinterval(function()
            local stat,res = pcall(fun)
            if not stat then 
              fibaro.error(nil,res)
            end
          end,math.floor(ms+0.5))
      end
      fibaro.setTimeout = function(ms,fun) return setTimeout(fun,ms) end
      fibaro.clearTimeout = function(ref) return clearTimeout(ref) end

      function json.decode(...)
        local stat,res = pcall(decode,...)
        if not stat then error(res,2) else return res end
      end
      function json.encode(...)
        local stat,res = pcall(encode,...)
        if not stat then error(res,2) else return res end
      end
    end

    local httpClient = net.HTTPClient -- protect success/error with pcall and print error
    function net.HTTPClient(args)
      local http = httpClient()
      return {
        request = function(_,url,opts)
          opts = copy(opts)
          local success,err = opts.success,opts.error
          if opts then
            opts.timeout = opts.timeout or args and args.timeout
          end
          if success then 
            opts.success=function(res) 
              local stat,r=pcall(success,res)
              if not stat then quickApp:error(r) end
            end 
          end
          if err then 
            opts.error=function(res) 
              local stat,r=pcall(err,res)
              if not stat then quickApp:error(r) end
            end 
          end
          return http:request(url,opts)
        end
      }
    end
  end
} --  Error handling 

-------------------- Utilities ----------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.utilities={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,utils,format = fibaro.debugFlags,fibaro.utils,string.format

    local _,copy = table.member,table.copy

    function table.copyShallow(t)
      if type(t)=='table' then
        local r={}; for k,v in pairs(t) do r[k]=v end 
        return r 
      else return t end
    end

    function table.mapAnd(f,l,s) s = s or 1; local e=true for i=s,table.maxn(l) do e = f(l[i]) if not e then return false end end return e end 
    function table.mapOr(f,l,s) s = s or 1; for i=s,table.maxn(l) do local e = f(l[i]) if e then return e end end return false end
    function table.reduce(f,l) local r = {}; for _,e in ipairs(l) do if f(e) then r[#r+1]=e end end; return r end
    function table.mapk(f,l) local r={}; for k,v in pairs(l) do r[k]=f(v) end; return r end
    function table.mapkv(f,l) local r={}; for k,v in pairs(l) do k,v=f(k,v) if k then r[k]=v end end; return r end
    function table.mapkl(f,l) local r={} for i,j in pairs(l) do r[#r+1]=f(i,j) end return r end
    function table.size(l) local n=0; for _,_ in pairs(l) do n=n+1 end return n end 

    function table.keyMerge(t1,t2)
      local res = copy(t1)
      for k,v in pairs(t2) do if t1[k]==nil then t1[k]=v end end
      return res
    end

    function table.keyIntersect(t1,t2)
      local res = {}
      for k,v in pairs(t1) do if t2[k] then res[k]=v end end
      return res
    end

    function table.zip(fun,a,b,c,d) 
      local res = {}
      for i=1,math.max(#a,#b) do res[#res+1] = fun(a[i],b[i],c and c[i],d and d[i]) end
      return res
    end

    for _,m in ipairs({"equal","copy","shallowCopy","member","delete","map","mapf","mapAnd","mapOr","reduce",
        "mapk","mapkv","size","keyMerge","keyIntersect","zip"}) do 
      utils[m]=table[m] 
    end

    function utils.gensym(s) return (s or "G")..fibaro._orgToString({}):match("%s(.*)") end

    function urlencode(str) -- very useful
      if str then
        str = str:gsub("\n", "\r\n")
        str = str:gsub("([^%w %-%_%.%~])", function(c)
            return ("%%%02X"):format(string.byte(c))
          end)
        str = str:gsub(" ", "%%20")
      end
      return str	
    end

    do
      local sortKeys = {"type","device","deviceID","id","value","oldValue","val","key","arg","event","events","msg","res"}
      local sortOrder={}
      for i,s in ipairs(sortKeys) do sortOrder[s]="\n"..string.char(i+64).." "..s end
      local function keyCompare(a,b)
        local av,bv = sortOrder[a] or a, sortOrder[b] or b
        return av < bv
      end

      -- our own json encode, as we don't have 'pure' json structs, and sorts keys in order (i.e. "stable" output)
      local function prettyJsonFlat(e0) 
        local res,seen = {},{}
        local function pretty(e)
          local t = type(e)
          if t == 'string' then res[#res+1] = '"' res[#res+1] = e res[#res+1] = '"'
          elseif t == 'number' then res[#res+1] = e
          elseif t == 'boolean' or t == 'function' or t=='thread' or t=='userdata' then res[#res+1] = tostring(e)
          elseif t == 'table' then
            if next(e)==nil then res[#res+1]='{}'
            elseif seen[e] then res[#res+1]="..rec.."
            elseif e[1] or #e>0 then
              seen[e]=true
              res[#res+1] = "[" pretty(e[1])
              for i=2,#e do res[#res+1] = "," pretty(e[i]) end
              res[#res+1] = "]"
            else
              seen[e]=true
              if e._var_  then res[#res+1] = format('"%s"',e._str) return end
              local k = {} for key,_ in pairs(e) do k[#k+1] = tostring(key) end
              table.sort(k,keyCompare)
              if #k == 0 then res[#res+1] = "[]" return end
              res[#res+1] = '{'; res[#res+1] = '"' res[#res+1] = k[1]; res[#res+1] = '":' t = k[1] pretty(e[t])
              for i=2,#k do
                res[#res+1] = ',"' res[#res+1] = k[i]; res[#res+1] = '":' t = k[i] pretty(e[t])
              end
              res[#res+1] = '}'
            end
          elseif e == nil then res[#res+1]='null'
          else error("bad json expr:"..tostring(e)) end
        end
        pretty(e0)
        return table.concat(res)
      end
      json.encodeFast = prettyJsonFlat
    end

    do -- Used for print device table structs - sortorder for device structs
      local sortKeys = {
        'id','name','roomID','type','baseType','enabled','visible','isPlugin','parentId','viewXml','configXml',
        'interfaces','properties','view', 'actions','created','modified','sortOrder'
      }
      local sortOrder={}
      for i,s in ipairs(sortKeys) do sortOrder[s]="\n"..string.char(i+64).." "..s end
      local function keyCompare(a,b)
        local av,bv = sortOrder[a] or a, sortOrder[b] or b
        return av < bv
      end

      local function prettyJsonStruct(t0)
        local res = {}
        local function isArray(t) return type(t)=='table' and t[1] end
        local function isEmpty(t) return type(t)=='table' and next(t)==nil end
        local function printf(tab,fmt,...) res[#res+1] = string.rep(' ',tab)..format(fmt,...) end
        local function pretty(tab,t,key)
          if type(t)=='table' then
            if isEmpty(t) then printf(0,"[]") return end
            if isArray(t) then
              printf(key and tab or 0,"[\n")
              for i,k in ipairs(t) do
                local _ = pretty(tab+1,k,true)
                if i ~= #t then printf(0,',') end
                printf(tab+1,'\n')
              end
              printf(tab,"]")
              return true
            end
            local r = {}
            for k,_ in pairs(t) do r[#r+1]=k end
            table.sort(r,keyCompare)
            printf(key and tab or 0,"{\n")
            for i,k in ipairs(r) do
              printf(tab+1,'"%s":',k)
              local _ =  pretty(tab+1,t[k])
              if i ~= #r then printf(0,',') end
              printf(tab+1,'\n')
            end
            printf(tab,"}")
            return true
          elseif type(t)=='number' then
            printf(key and tab or 0,"%s",t)
          elseif type(t)=='boolean' then
            printf(key and tab or 0,"%s",t and 'true' or 'false')
          elseif type(t)=='string' then
            printf(key and tab or 0,'"%s"',t:gsub('(%")','\\"'))
          end
        end
        pretty(0,t0,true)
        return table.concat(res,"")
      end
      json.encodeFormated = prettyJsonStruct
    end

    function utils.printBuffer(pre) 
      local self2,buff = {},pre and {pre} or {}
      function self2.printf(_,fmt,...) buff[#buff+1]=format(fmt,...) end --ignore 212/self
      function self2.add(_,str) buff[#buff+1]=tostring(str) end
      function self2.trim(_,n) for _=1,#buff-n do table.remove(buff,#buff) end end
      self2.buffer = buff
      function self2.tostring(_,space) return table.concat(buff,space) end
      return self2
    end

    function utils.basicAuthorization(user,password) return "Basic "..utils.base64encode(user..":"..password) end
    function utils.base64encode(data)
      __assert_type(data,"string")
      local bC='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
      return ((data:gsub('.', function(x) 
              local r,b='',x:byte() for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
              return r;
            end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
            if (#x < 6) then return '' end
            local c=0
            for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
            return bC:sub(c+1,c+1)
          end)..({ '', '==', '=' })[#data%3+1])
    end

    function fibaro.sequence(...)
      local args,i,ref = {...},1,{}
      local function stepper()
        if i <= #args then
          local arg = args[i]
          i=i+1
          if type(arg)=='number' then 
            ref[1]=setTimeout(stepper,arg)
          elseif type(arg)=='table' and type(arg[1])=='function' then
            pcall(table.unpack(arg))
            ref[1]=setTimeout(stepper,0)
          end
        end
      end
      ref[1]=setTimeout(stepper,0)
      return ref
    end

    function fibaro.stopSequence(ref) clearTimeout(ref[1]) end

  end
} -- Utilities

-------------------- Sun calc ----------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.sun={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,utils,format = fibaro.debugFlags,fibaro.utils,string.format
    ---@return number
    local function sunturnTime(date, rising, latitude, longitude, zenith, local_offset)
      local rad,deg,floor = math.rad,math.deg,math.floor
      local frac = function(n) return n - floor(n) end
      local cos = function(d) return math.cos(rad(d)) end
      local acos = function(d) return deg(math.acos(d)) end
      local sin = function(d) return math.sin(rad(d)) end
      local asin = function(d) return deg(math.asin(d)) end
      local tan = function(d) return math.tan(rad(d)) end
      local atan = function(d) return deg(math.atan(d)) end

      local function day_of_year(date2)
        local n1 = floor(275 * date2.month / 9)
        local n2 = floor((date2.month + 9) / 12)
        local n3 = (1 + floor((date2.year - 4 * floor(date2.year / 4) + 2) / 3))
        return n1 - (n2 * n3) + date2.day - 30
      end

      local function fit_into_range(val, min, max)
        local range,count = max - min,nil
        if val < min then count = floor((min - val) / range) + 1; return val + count * range
        elseif val >= max then count = floor((val - max) / range) + 1; return val - count * range
        else return val end
      end

      -- Convert the longitude to hour value and calculate an approximate time
      local n,lng_hour,t =  day_of_year(date), longitude / 15,nil
      if rising then t = n + ((6 - lng_hour) / 24) -- Rising time is desired
      else t = n + ((18 - lng_hour) / 24) end -- Setting time is desired
      local M = (0.9856 * t) - 3.289 -- Calculate the Sun^s mean anomaly
      -- Calculate the Sun^s true longitude
      local L = fit_into_range(M + (1.916 * sin(M)) + (0.020 * sin(2 * M)) + 282.634, 0, 360)
      -- Calculate the Sun^s right ascension
      local RA = fit_into_range(atan(0.91764 * tan(L)), 0, 360)
      -- Right ascension value needs to be in the same quadrant as L
      local Lquadrant = floor(L / 90) * 90
      local RAquadrant = floor(RA / 90) * 90
      RA = RA + Lquadrant - RAquadrant; RA = RA / 15 -- Right ascension value needs to be converted into hours
      local sinDec = 0.39782 * sin(L) -- Calculate the Sun's declination
      local cosDec = cos(asin(sinDec))
      local cosH = (cos(zenith) - (sinDec * sin(latitude))) / (cosDec * cos(latitude)) -- Calculate the Sun^s local hour angle
      if rising and cosH > 1 then return -1 --"N/R" -- The sun never rises on this location on the specified date
      elseif cosH < -1 then return -1 end --"N/S" end -- The sun never sets on this location on the specified date

      local H -- Finish calculating H and convert into hours
      if rising then H = 360 - acos(cosH)
      else H = acos(cosH) end
      H = H / 15
      local T = H + RA - (0.06571 * t) - 6.622 -- Calculate local mean time of rising/setting
      local UT = fit_into_range(T - lng_hour, 0, 24) -- Adjust back to UTC
      local LT = UT + local_offset -- Convert UT value to local time zone of latitude/longitude
---@diagnostic disable-next-line: missing-fields
      return os.time({day = date.day,month = date.month,year = date.year,hour = floor(LT),min = math.modf(frac(LT) * 60)})
    end

---@diagnostic disable-next-line: param-type-mismatch
    local function getTimezone() local now = os.time() return os.difftime(now, os.time(os.date("!*t", now))) end

    function utils.sunCalc(time)
      local hc3Location = api.get("/settings/location")
      local lat = hc3Location.latitude or 0
      local lon = hc3Location.longitude or 0
      local utc = getTimezone() / 3600
      local zenith,zenith_twilight = 90.83, 96.0 -- sunset/sunrise 90°50′, civil twilight 96°0′

      local date = os.date("*t",time or os.time())
      if date.isdst then utc = utc + 1 end
      local rise_time = os.date("*t", sunturnTime(date, true, lat, lon, zenith, utc))
      local set_time = os.date("*t", sunturnTime(date, false, lat, lon, zenith, utc))
      local rise_time_t = os.date("*t", sunturnTime(date, true, lat, lon, zenith_twilight, utc))
      local set_time_t = os.date("*t", sunturnTime(date, false, lat, lon, zenith_twilight, utc))
      local sunrise = format("%.2d:%.2d", rise_time.hour, rise_time.min)
      local sunset = format("%.2d:%.2d", set_time.hour, set_time.min)
      local sunrise_t = format("%.2d:%.2d", rise_time_t.hour, rise_time_t.min)
      local sunset_t = format("%.2d:%.2d", set_time_t.hour, set_time_t.min)
      return sunrise, sunset, sunrise_t, sunset_t
    end
  end 
} -- Sun calc

-------------------- Cron ----------------------------------------------
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
            for _,args in pairs(jobs) do
--            setTimeout(function() -- what is better?
              if args.test() then stat,res = pcall(args.fun,table.unpack(args.args)) else stat=true end
              if not stat then fibaro.error(__TAG,res) end
--              end,0)
            end
            nxt = nxt + 60
            timer['%TIMER%']=setTimeout(loop,1000*(nxt-os.time()))
          end
          timer = setTimeout(loop,1000*(nxt-os.time()))
        end
        return timer
      end

      function fibaro.cron(str,fun,...)
        jobs[str]={fun=fun,args={...},test=dateTest(str)}
        return cronLoop()
      end
      function fibaro.removeCronJob(str)
        jobs[str]=nil
      end
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

--------------------- HC3 functions --------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.hc3={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,format = fibaro.debugFlags,string.format
    local HC3version,IPaddress

    function fibaro.HC3version(version)     -- Return/optional check HC3 version
      if HC3version == nil then HC3version = api.get("/settings/info").currentVersion.version end
      if version then return version >= HC3version else return HC3version end 
    end

    function fibaro.getIPaddress(name)
      if IPaddress then return IPaddress end
      if hc3_emulator then return hc3_emulator.IPaddress
      else
        name = name or ".*"
        local networkdata = api.get("/proxy?url=http://localhost:11112/api/settings/network")
        for n,d in pairs(networkdata.networkConfig or {}) do
          if n:match(name) and d.enabled then IPaddress = d.ipConfig.ip; return IPaddress end
        end
      end
    end

    if not fibaro.callUI then
      fibaro.callUI = function(id, action, element, value)
        __assert_type(id,"number") __assert_type(action,"string") __assert_type(element,"string")
        value = value==nil and "null" or value 
        local _, code = api.get(format("/plugins/callUIEvent?deviceID=%s&eventType=%s&elementName=%s&value=%s",id,action,element,value))
        if code == 404 then error(format("Device %s does not exists",id), 3) end
      end
    end
  end
} -- HC3 functions

--------------------- Time functions ------------------------------------------
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

---@diagnostic disable-next-line: param-type-mismatch
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

--------------------- Trace functions ------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.trace={ author = "jan@gabrielsson.com", version = '0.4', depends={}, init = function()
    local _,_ = fibaro.debugFlags,string.format
  end
} -- Trace functions

--------------------- Debug functions -----------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.debug={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local debugFlags,utils,format = fibaro.debugFlags,fibaro.utils,string.format
    local function setDefault(v1,v2) if v1==nil then return v2 else return v1 end end

    local fformat
    debugFlags.debugLevel=nil
    debugFlags.traceLevel=nil
    debugFlags.notifyError=setDefault(debugFlags.notifyError,true)
    debugFlags.notifyWarning=setDefault(debugFlags.notifyWarning,true)
    debugFlags.onaction=setDefault(debugFlags.onaction,true)
    debugFlags.uievent=setDefault(debugFlags.uievent,true)
    debugFlags.json=setDefault(debugFlags.json,true)
    debugFlags.html=setDefault(debugFlags.html,true)
    debugFlags.reuseNotifies=setDefault(debugFlags.reuseNotifies,true)
    debugFlags.logTrigger=setDefault(debugFlags.logTrigger,true)

-- Add notification to notification center
    local cachedNots = {}
    local function notify(priority, text, reuse)
      local id = plugin.mainDeviceId
      local name = quickApp and quickApp.name or "Scene"
      assert(({info=true,warning=true,alert=true})[priority],"Wrong 'priority' - info/warning/alert")
      local title = text:match("(.-)[:%s]") or format("%s deviceId:%d",name,id)

      if reuse==nil then reuse = debugFlags.reuseNotifies end
      local msgId = nil
      local data = {
        canBeDeleted = true,
        wasRead = false,
        priority = priority,
        type = "GenericDeviceNotification",
        data = {
          sceneId = sceneId,
          deviceId = id,
          subType = "Generic",
          title = title,
          text = tostring(text)
        }
      }
      local nid = title..id
      if reuse then
        if cachedNots[nid] then
          msgId = cachedNots[nid]
        else
          for _,n in ipairs(api.get("/notificationCenter") or {}) do
            if n.data and (n.data.deviceId == id or n.data.sceneeId == id) and n.data.title == title then
              msgId = n.id; break
            end
          end
        end
      end
      if msgId then
        api.put("/notificationCenter/"..msgId, data)
      else
        local d = api.post("/notificationCenter", data)
        if d then cachedNots[nid] = d.id end
      end
    end
    utils.notify = notify

    local oldPrint = print
    local inhibitPrint = {['onAction: ']='onaction', ['UIEvent: ']='uievent'}
    function print(a,...) 
      if not inhibitPrint[a] or debugFlags[inhibitPrint[a]] then
        oldPrint(a,...) 
      end
    end

    local htmlCodes={['\n']='<br>', [' ']='&nbsp;'}
    local function fix(str) return str:gsub("([\n%s])",function(c) return htmlCodes[c] or c end) end
    local function htmlTransform(str)
      local hit = false
      str = str:gsub("([^<]*)(<.->)([^<]*)",function(s1,s2,s3) hit=true
          return (s1~="" and fix(s1) or "")..s2..(s3~="" and fix(s3) or "") 
        end)
      return hit and str or fix(str)
    end

    function fformat(fmt,...)
      local args = {...}
      if #args == 0 then return tostring(fmt) end
      for i,v in ipairs(args) do if type(v)=='table' then args[i]=tostring(v) end end
      return (debugFlags.html and not hc3_emulator) and htmlTransform(format(fmt,table.unpack(args))) or format(fmt,table.unpack(args))
    end
    fibaro.fformat = fformat

    local function arr2str(del,...)
      local args,res = {...},{}
      for i=1,#args do if args[i]~=nil then res[#res+1]=tostring(args[i]) end end 
      return (debugFlags.html and not hc3_emulator) and htmlTransform(table.concat(res,del)) or table.concat(res,del)
    end 
    fibaro.arr2str = arr2str

    fibaro.stringTrunc = { 100, 160, 1000 }
    local function print_debug(typ,tag,str)
      --__fibaro_add_debug_message(tag or __TAG,str or "",typ or "debug")
      local m,s=str:match("^##(%d)(.*)") -- truncate output
      if m then 
        str=s
        local sl,ml = str:len()-3,fibaro.stringTrunc[tonumber(m)]
        if ml and sl > ml then str=str:sub(1,ml).."..." end
      end
      if type(tag)=='number' then tag = nil end
      __fibaro_add_debug_message(tag or __TAG, str, typ)
      --api.post("/debugMessages",{message=str,messageType=typ or "debug",tag=tag or __TAG})
      if typ=='error' and debugFlags.eventError then
        fibaro.post({type='error',message=str,tag=tag})
      elseif typ=='warning' and debugFlags.eventWarning then
        fibaro.post({type='warning',message=str,tag=tag})
      end
      return str
    end

    function fibaro.debug(tag,...) 
      if not(type(tag)=='number' and tag > (debugFlags.debugLevel or 0)) then 
        return print_debug('debug',tag,arr2str(" ",...)) 
      else return "" end 
    end
    function fibaro.trace(tag,a,...)
      if a and inhibitPrint[a] and debugFlags[inhibitPrint[a]]==false then return end
      if not(type(tag)=='number' and tag > (debugFlags.traceLevel or 0)) then 
        return print_debug('trace',tag,arr2str(" ",a,...)) 
      else return "" end 
    end
    function fibaro.error(tag,...)
      local str = print_debug('error',tag,arr2str(" ",...))
      if debugFlags.notifyError then notify("alert",str) end
      return str
    end
    function fibaro.warning(tag,...) 
      local str = print_debug('warning',tag,arr2str(" ",...))
      if debugFlags.notifyWarning then notify("warning",str) end
      return str
    end
    function fibaro.debugf(tag,fmt,...) 
      if not(type(tag)=='number' and tag > (debugFlags.debugLevel or 0)) then 
        return print_debug('debug',tag,fformat(fmt,...)) 
      else return "" end 
    end
    function fibaro.tracef(tag,fmt,...) 
      if not(type(tag)=='number' and tag > (debugFlags.traceLevel or 0)) then 
        return print_debug('trace',tag,fformat(fmt,...)) 
      else return "" end 
    end
    function fibaro.errorf(tag,fmt,...)
      local str = print_debug('error',tag,fformat(fmt,...)) 
      if debugFlags.notifyError then notify("alert",str) end
      return str
    end
    function fibaro.warningf(tag,fmt,...) 
      local str = print_debug('warning',tag,fformat(fmt,...)) 
      if debugFlags.notifyWarning then notify("warning",str) end
      return str
    end

    for _,f in ipairs({'debugf','tracef','warningf','errorf'}) do
      fibaro[f] = fibaro.protectFun(fibaro[f],f,2)
    end

  end -- Debug functions
} -- Debug functions

--------------------- Scene function  -----------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.scene={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,_ = fibaro.debugFlags,string.format
    function fibaro.isSceneEnabled(sceneID) 
      __assert_type(sceneID,"number" )
      return (api.get("/scenes/"..sceneID) or { enabled=false }).enabled 
    end

    function fibaro.setSceneEnabled(sceneID,enabled) 
      __assert_type(sceneID,"number" )   __assert_type(enabled,"boolean" )
      return api.put("/scenes/"..sceneID,{enabled=enabled}) 
    end

    function fibaro.getSceneRunConfig(sceneID)
      __assert_type(sceneID,"number" )
      return api.get("/scenes/"..sceneID).mode 
    end

    function fibaro.setSceneRunConfig(sceneID,runConfig)
      __assert_type(sceneID,"number" )
      assert(({automatic=true,manual=true})[runConfig],"runconfig must be 'automatic' or 'manual'")
      return api.put("/scenes/"..sceneID, {mode = runConfig}) 
    end

    function fibaro.getSceneByName(name)
      __assert_type(name,"string" )
      for _,s in ipairs(api.get("/scenes")) do
        if s.name==name then return s end
      end
    end

  end
} -- Scene function

--------------------- Globals --------------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.globals={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,_ = fibaro.debugFlags,string.format
    function fibaro.getAllGlobalVariables() 
      return table.map(function(v) return v.name end,api.get("/globalVariables")) 
    end

    function fibaro.createGlobalVariable(name,value,options)
      __assert_type(name,"string")
      if not fibaro.existGlobalVariable(name) then 
        value = tostring(value)
        local args = table.copy(options or {})
        args.name,args.value=name,value
        return api.post("/globalVariables",args)
      end
    end

    function fibaro.deleteGlobalVariable(name) 
      __assert_type(name,"string")
      return api.delete("/globalVariables/"..name) 
    end

    function fibaro.existGlobalVariable(name)
      __assert_type(name,"string")
      return api.get("/globalVariables/"..name) and true 
    end

    function fibaro.getGlobalVariableType(name)
      __assert_type(name,"string")
      local v = api.get("/globalVariables/"..name) or {}
      return v.isEnum,v.readOnly
    end

    function fibaro.getGlobalVariableLastModified(name)
      __assert_type(name,"string")
      return (api.get("/globalVariables/"..name) or {}).modified 
    end
  end
} -- Globals

--------------------- Custom events --------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.customEvents={ author = "jan@gabrielsson.com", version = '0.41', depends={'base'},
  init = function()
    local _,_ = fibaro.debugFlags,string.format
    function fibaro.getAllCustomEvents() 
      return table.map(function(v) return v.name end,api.get("/customEvents") or {}) 
    end

    function fibaro.createCustomEvent(name,userDescription) 
      __assert_type(name,"string" )
      return api.post("/customEvents",{name=name,userDescription=userDescription or ""})
    end

    function fibaro.deleteCustomEvent(name) 
      __assert_type(name,"string" )
      return api.delete("/customEvents/"..name) 
    end

    function fibaro.existCustomEvent(name) 
      __assert_type(name,"string" )
      return api.get("/customEvents/"..name) and true 
    end
  end 
} -- Custom events

--------------------- Profiles -------------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.profiles={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,_ = fibaro.debugFlags,string.format
    function fibaro.activeProfile(id)
      if id then
        if type(id)=='string' then id = fibaro.profileNameToId(id) end
        assert(id,"fibaro.activeProfile(id) - no such id/name")
        return api.put("/profiles",{activeProfile=id}) and id
      end
      return api.get("/profiles").activeProfile 
    end

    function fibaro.profileIdtoName(pid)
      __assert_type(pid,"number")
      for _,p in ipairs(api.get("/profiles").profiles or {}) do 
        if p.id == pid then return p.name end 
      end 
    end

    function fibaro.profileNameToId(name)
      __assert_type(name,"string")
      for _,p in ipairs(api.get("/profiles").profiles or {}) do 
        if p.name == name then return p.id end 
      end 
    end
  end 
} -- Profiles

--------------------- Alarm ------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.alarm={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
init = function()
  local _,_ = fibaro.debugFlags,string.format
  function fibaro.partitionIdToName(pid)
    __assert_type(pid,"number")
    return (api.get("/alarms/v1/partitions/"..pid) or {}).name 
  end
  
  function fibaro.partitionNameToId(name)
    assert(type(name)=='string',"Alarm partition name not a string")
    for _,p in ipairs(api.get("/alarms/v1/partitions") or {}) do
      if p.name == name then return p.id end
    end
  end
  
  -- Returns devices breached in partition 'pid'
  function fibaro.getBreachedDevicesInPartition(pid)
    assert(type(pid)=='number',"Alarm partition id not a number")
    local p,res = api.get("/alarms/v1/partitions/"..pid),{}
    for _,d in ipairs((p or {}).devices or {}) do
      if fibaro.getValue(d,"value") then res[#res+1]=d end
    end
    return res
  end
  
  -- helper function
  local function filterPartitions(filter)
    local res = {}
    for _,p in ipairs(api.get("/alarms/v1/partitions") or {}) do if filter(p) then res[#res+1]=p.id end end
    return res
  end
  
  -- Return all partitions ids
  function fibaro.getAllPartitions() return filterPartitions(function() return true end) end
  
  -- Return partitions that are armed
  function fibaro.getArmedPartitions() return filterPartitions(function(p) return p.armed end) end
  
  -- Return partitions that are about to be armed
  function fibaro.getActivatedPartitions() return filterPartitions(function(p) return p.secondsToArm end) end
  
  -- Return breached partitions
  function fibaro.getBreachedPartitions() return api.get("/alarms/v1/partitions/breached") or {} end
  
  --If you want to list all devices that can be part of a alarm partition/zone you can do
  function fibaro.getAlarmDevices() return api.get("/alarms/v1/devices/") end

  function fibaro.armPartition(id)
    if id == 0 then
      return api.post("/alarms/v1/partitions/actions/arm")
    else
      return api.post("/alarms/v1/partitions/"..id.."/actions/arm")
    end
  end
  
  function fibaro.unarmPartition(id)
    if id == 0 then
      return api.delete("/alarms/v1/partitions/actions/arm")
    else
      return api.delete("/alarms/v1/partitions/"..id.."/actions/arm")
    end
  end

  function fibaro.tryArmPartition(id)
    local res,code
    if id == 0 then
      res,code = api.post("/alarms/v1/partitions/actions/tryArm")
      if type(res) == 'table' then
        local r = {}
        for _,p in ipairs(res) do r[p.id]=p.breachedDevices end
        return next(r) and r or nil
      else
        return nil
      end
    else
      local res,code = api.post("/alarms/v1/partitions/"..id.."/actions/tryArm")
      if res.armDelayed and #res.armDelayed > 0 then return {[id]=res.breachedDevices} else return nil end
    end
  end

end
} -- Alarm

--------------------- Weather --------------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.weather={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,_ = fibaro.debugFlags,string.format
    fibaro.weather = {}
    function fibaro.weather.temperature() return api.get("/weather").Temperature end
    function fibaro.weather.temperatureUnit() return api.get("/weather").TemperatureUnit end
    function fibaro.weather.humidity() return api.get("/weather").Humidity end
    function fibaro.weather.wind() return api.get("/weather").Wind end
    function fibaro.weather.weatherCondition() return api.get("/weather").WeatherCondition end
    function fibaro.weather.conditionCode() return api.get("/weather").ConditionCode end
  end
} -- Weather

--------------------- Climate panel ----------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.climate={ author = "jan@gabrielsson.com", version = '0.4',depends={'base'},
  init = function()
    local _,_ = fibaro.debugFlags,string.format
    --Returns mode - "Manual", "Vacation", "Schedule"
    function fibaro.getClimateMode(id)
      return (api.get("/panels/climate/"..id) or {}).mode
    end

--Returns the currents mode "mode", or sets it - "Auto", "Off", "Cool", "Heat"
    function fibaro.climateModeMode(id,mode)
      if mode==nil then return api.get("/panels/climate/"..id).properties.mode end
      assert(({Auto=true,Off=true,Cool=true,Heat=true})[mode],"Bad climate mode")
      return api.put("/panels/climate/"..id,{properties={mode=mode}})
    end

-- Set zone to scheduled mode
    function fibaro.setClimateZoneToScheduleMode(id)
      __assert_type(id, "number")
      return api.put('/panels/climate/'..id, {properties = {
            handTimestamp     = 0,
            vacationStartTime = 0,
            vacationEndTime   = 0
          }})
    end

-- Set zone to manual, incl. mode, time ( secs ), heat and cool temp
    function  fibaro.setClimateZoneToManualMode(id, mode, time, heatTemp, coolTemp)
      __assert_type(id, "number") __assert_type(mode, "string")
      assert(({Auto=true,Off=true,Cool=true,Heat=true})[mode],"Bad climate mode")
      return api.put('/panels/climate/'..id, { properties = { 
            handMode            = mode, 
            vacationStartTime   = 0, 
            vacationEndTime     = 0,
            handTimestamp       = tonumber(time) and os.time()+time or math.tointeger(2^32-1),
            handSetPointHeating = tonumber(heatTemp) and heatTemp or nil,
            handSetPointCooling = tonumber(coolTemp) and coolTemp or nil
          }})
    end

-- Set zone to vacation, incl. mode, start (secs from now), stop (secs from now), heat and cool temp
    function fibaro.setClimateZoneToVacationMode(id, mode, start, stop, heatTemp, coolTemp)
      __assert_type(id,"number") __assert_type(mode,"string") __assert_type(start,"number") __assert_type(stop,"number")
      assert(({Auto=true,Off=true,Cool=true,Heat=true})[mode],"Bad climate mode")
      local now = os.time()
      return api.put('/panels/climate/'..id, { properties = {
            vacationMode            = mode,
            handTimestamp           = 0, 
            vacationStartTime       = now+start, 
            vacationEndTime         = now+stop,
            vacationSetPointHeating = tonumber(heatTemp) and heatTemp or nil,
            vacationSetPointCooling = tonumber(coolTemp) and coolTemp or nil
          }})
    end
  end 
} --- Climate panel

--------------------- sourceTrigger refreshStates ----------------------------
_MODULES.triggers={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local debugFlags,format = fibaro.debugFlags,string.format
    fibaro.REFRESH_STATES_INTERVAL = 1000
    fibaro.REFRESHICONSTATUS = "icon"
    local sourceTriggerCallbacks,refreshCallbacks,refreshRef,pollRefresh={},{},nil,nil
    local ENABLEDSOURCETRIGGERS,DISABLEDREFRESH={},{}
    local post,sourceTriggerTransformer,filter
    local member,equal = table.member,table.equal

    local EventTypes = { -- There are more, but these are what I seen so far...
      AlarmPartitionArmedEvent = function(d) post({type='alarm', property='armed', id = d.partitionId, value=d.armed}) end,
      AlarmPartitionBreachedEvent = function(d) post({type='alarm', property='breached', id = d.partitionId, value=d.breached}) end,
      HomeArmStateChangedEvent = function(d) post({type='alarm', property='homeArmed', value=d.newValue}) end,
      HomeDisarmStateChangedEvent = function(d) post({type='alarm', property='homeArmed', value=not d.newValue}) end,
      HomeBreachedEvent = function(d) post({type='alarm', property='homeBreached', value=d.breached}) end,
      WeatherChangedEvent = function(d) post({type='weather',property=d.change, value=d.newValue, old=d.oldValue}) end,
      GlobalVariableChangedEvent = function(d)
        if hc3_emulator and d.variableName==hc3_emulator.EM.EMURUNNING then return true end
        post({type='global-variable', name=d.variableName, value=d.newValue, old=d.oldValue}) 
      end,
      GlobalVariableAddedEvent = function(d) 
        post({type='global-variable', name=d.variableName, value=d.value, old=nil}) 
      end,
      DevicePropertyUpdatedEvent = function(d)
        if d.property=='quickAppVariables' then 
          local old={}; for _,v in ipairs(d.oldValue) do old[v.name] = v.value end -- Todo: optimize
          for _,v in ipairs(d.newValue) do
            if not equal(v.value,old[v.name]) then
              post({type='quickvar', id=d.id, name=v.name, value=v.value, old=old[v.name]})
            end
          end
        else
          if d.property == fibaro.REFRESHICONSTATUS or filter(d.id,d.property,d.newValue) then return end
          post({type='device', id=d.id, property=d.property, value=d.newValue, old=d.oldValue})
        end
      end,
      CentralSceneEvent = function(d) 
        d.id = d.id or d.deviceId
        d.icon=nil 
        post({type='device', property='centralSceneEvent', id=d.id, value={keyId=d.keyId, keyAttribute=d.keyAttribute}}) 
      end,
      SceneActivationEvent = function(d) 
        d.id = d.id or d.deviceId
        post({type='device', property='sceneActivationEvent', id=d.id, value={sceneId=d.sceneId}})     
      end,
      AccessControlEvent = function(d) 
        post({type='device', property='accessControlEvent', id=d.id, value=d}) 
      end,
      CustomEvent = function(d) 
        local value = api.get("/customEvents/"..d.name) 
        post({type='custom-event', name=d.name, value=value and value.userDescription}) 
      end,
      PluginChangedViewEvent = function(d) post({type='PluginChangedViewEvent', value=d}) end,
      WizardStepStateChangedEvent = function(d) post({type='WizardStepStateChangedEvent', value=d})  end,
      UpdateReadyEvent = function(d) post({type='updateReadyEvent', value=d}) end,
      DeviceRemovedEvent = function(d)  post({type='deviceEvent', id=d.id, value='removed'}) end,
      DeviceChangedRoomEvent = function(d)  post({type='deviceEvent', id=d.id, value='changedRoom'}) end,
      DeviceCreatedEvent = function(d)  post({type='deviceEvent', id=d.id, value='created'}) end,
      DeviceModifiedEvent = function(d) post({type='deviceEvent', id=d.id, value='modified'}) end,
      PluginProcessCrashedEvent = function(d) post({type='deviceEvent', id=d.deviceId, value='crashed', error=d.error}) end,
      SceneStartedEvent = function(d)   post({type='sceneEvent', id=d.id, value='started'}) end,
      SceneFinishedEvent = function(d)  post({type='sceneEvent', id=d.id, value='finished'})end,
      SceneRunningInstancesEvent = function(d) post({type='sceneEvent', id=d.id, value='instance', instance=d}) end,
      SceneRemovedEvent = function(d)  post({type='sceneEvent', id=d.id, value='removed'}) end,
      SceneModifiedEvent = function(d)  post({type='sceneEvent', id=d.id, value='modified'}) end,
      SceneCreatedEvent = function(d)  post({type='sceneEvent', id=d.id, value='created'}) end,
      OnlineStatusUpdatedEvent = function(d) post({type='onlineEvent', value=d.online}) end,
      --onUIEvent = function(d) post({type='uievent', deviceID=d.deviceId, name=d.elementName}) end,
      ActiveProfileChangedEvent = function(d) 
        post({type='profile',property='activeProfile',value=d.newActiveProfile, old=d.oldActiveProfile}) 
      end,
      ClimateZoneChangedEvent = function(d) --ClimateZoneChangedEvent
        if d.changes and type(d.changes)=='table' then
          for _,c in ipairs(d.changes) do
            c.type,c.id='ClimateZone',d.id
            post(c)
          end
        end
      end,
      ClimateZoneSetpointChangedEvent = function(d) d.type = 'ClimateZoneSetpoint' post(d) end,
      NotificationCreatedEvent = function(d) post({type='notification', id=d.id, value='created'}) end,
      NotificationRemovedEvent = function(d) post({type='notification', id=d.id, value='removed'}) end,
      NotificationUpdatedEvent = function(d) post({type='notification', id=d.id, value='updated'}) end,
      RoomCreatedEvent = function(d) post({type='room', id=d.id, value='created'}) end,
      RoomRemovedEvent = function(d) post({type='room', id=d.id, value='removed'}) end,
      RoomModifiedEvent = function(d) post({type='room', id=d.id, value='modified'}) end,
      SectionCreatedEvent = function(d) post({type='section', id=d.id, value='created'}) end,
      SectionRemovedEvent = function(d) post({type='section', id=d.id, value='removed'}) end,
      SectionModifiedEvent = function(d) post({type='section', id=d.id, value='modified'}) end,
      QuickAppFilesChangedEvent = function(_) end,
      ZwaveDeviceParametersChangedEvent = function(_) end,
      ZwaveNodeAddedEvent = function(_) end,
      RefreshRequiredEvent = function(_) end,
      DeviceFirmwareUpdateEvent = function(_) end,
      GeofenceEvent = function(d) 
        post({type='location',id=d.userId,property=d.locationId,value=d.geofenceAction,timestamp=d.timestamp})
      end,
      DeviceActionRanEvent = function(d,e)
        if e.sourceType=='user' then  
          post({type='user',id=e.sourceId,value='action',data=d})
        elseif e.sourceType=='system' then 
          post({type='system',value='action',data=d})
        end
      end,
    }

--  {"date":"08:24 | 9.7.2022","changes":[],"events":[{"objects":[{"objectType":"device","objectId":756}],"type":"DeviceActionRanEvent","created":1657347877,"sourceId":2,"data":{"args":[],"actionName":"turnOn","id":756},"sourceType":"user"}],"last":341112,"status":"IDLE","timestamp":1657347877}

    function fibaro.registerSourceTriggerCallback(callback)
      __assert_type(callback,"function")
      if member(callback,sourceTriggerCallbacks) then return end
      if #sourceTriggerCallbacks == 0 then
        fibaro.registerRefreshStatesCallback(sourceTriggerTransformer)
      end
      sourceTriggerCallbacks[#sourceTriggerCallbacks+1] = callback
    end

    function fibaro.unregisterSourceTriggerCallback(callback)
      __assert_type(callback,"function")
      if member(callback,sourceTriggerCallbacks) then sourceTriggerCallbacks:remove(callback) end
      if #sourceTriggerCallbacks == 0 then
        fibaro.unregisterRefreshStatesCallback(sourceTriggerTransformer) 
      end
    end

    function post(ev)
      if ENABLEDSOURCETRIGGERS[ev.type] then
        if #sourceTriggerCallbacks==0 then return end
        if debugFlags.sourceTrigger then fibaro.debug(__TAG,format("##1SourceTrigger:%s",tostring(ev))) end
        ev._trigger=true
        for _,cb in ipairs(sourceTriggerCallbacks) do
          setTimeout(function() cb(ev) end,0) 
        end
      end
    end

    function sourceTriggerTransformer(e)
      local handler = EventTypes[e.type]
      if handler then handler(e.data,e)
      elseif handler==nil and fibaro._UNHANDLED_REFRESHSTATES then 
        fibaro.debugf(__TAG,format("[Note] Unhandled refreshState/sourceTrigger:%s -- please report",tostring(e))) 
      end
    end

    function fibaro.enableSourceTriggers(trigger)
      if type(trigger)~='table' then  trigger={trigger} end
      for _,t in  ipairs(trigger) do ENABLEDSOURCETRIGGERS[t]=true end
    end
    fibaro.enableSourceTriggers({"device","alarm","global-variable","custom-event","quickvar"})

    function fibaro.disableSourceTriggers(trigger)
      if type(trigger)~='table' then  trigger={trigger} end
      for _,t in  ipairs(trigger) do ENABLEDSOURCETRIGGERS[t]=nil end
    end

    local propFilters = {}
    function fibaro.sourceTriggerDelta(id,prop,value)
      __assert_type(id,"number")
      __assert_type(prop,"string")
      local d = propFilters[id] or {}
      d[prop] =  {delta = value}
      propFilters[id] = d
    end

    function filter(id,prop,new)
      local d = (propFilters[id] or {})[prop]
      if d then
        if d.last == nil then 
          d.last = new
          return false
        else
          if math.abs(d.last-new) >= d.delta then
            d.last = new
            return false
          else return true end
        end
      else return false end
    end

    fibaro._REFRESHSTATERATE = 1000
    local lastRefresh = 0
    net = net or { HTTPClient = function() end  }
    local http = net.HTTPClient()
    math.randomseed(os.time())
    local urlTail = "&lang=en&rand="..math.random(2000,4000).."&logs=false"
    function pollRefresh()
      local a,b = http:request("http://127.0.0.1:11111/api/refreshStates?last=" .. lastRefresh..urlTail,{
          success=function(res)
            local states = res.status == 200 and json.decode(res.data)
            if states then
              lastRefresh=states.last
              if states.events and #states.events>0 then 
                for _,e in ipairs(states.events) do
                  --print("XX",e)
                  fibaro._postRefreshState(e)
                end
              end
              if debugFlags.logTrigger and states.changes and #states.changes>0 then
                for _,e in ipairs(states.changes) do
                  if e.log then
                    fibaro._postRefreshState({type='DevicePropertyUpdatedEvent', data={id=e.id,property='log',newValue=e.log}})
                  end
                end
              end 
            end
            refreshRef = setTimeout(pollRefresh,fibaro.REFRESH_STATES_INTERVAL or 0)
          end,
          error=function(res) 
            fibaro.error(__TAG,format("refreshStates:%s",res))
            refreshRef = setTimeout(pollRefresh,fibaro.REFRESH_STATES_INTERVAL or 0)
          end,
        })
    end

    function fibaro.registerRefreshStatesCallback(callback)
      __assert_type(callback,"function")
      if member(callback,refreshCallbacks) then return end
      refreshCallbacks[#refreshCallbacks+1] = callback
      if not refreshRef then refreshRef = setTimeout(pollRefresh,0) end
      if debugFlags._refreshStates then fibaro.debug(__TAG,"Polling for refreshStates") end
    end

    function fibaro.unregisterRefreshStatesCallback(callback)
      table.delete(callback,refreshCallbacks)
      if #refreshCallbacks == 0 then
        if refreshRef then clearTimeout(refreshRef); refreshRef = nil end
        if debugFlags._refreshStates then fibaro.debug(nil,"Stop polling for refreshStates") end
      end
    end

    function fibaro.enableRefreshStatesTypes(typs) 
      if  type(typs)~='table' then typs={typs} end
      for _,t in ipairs(typs) do DISABLEDREFRESH[t]=nil end
    end

    function fibaro.disableRefreshStatesTypes(typs)
      if  type(typs)~='table' then typs={typs} end
      for _,t in ipairs(typs) do DISABLEDREFRESH[t]=true end
    end

    function fibaro._postSourceTrigger(trigger) post(trigger) end

    function fibaro._postRefreshState(event)
      if debugFlags._allRefreshStates then fibaro.debug(__TAG,format("##1RefreshState:%s",json.encodeFast(event))) end
      if #refreshCallbacks>0 and not DISABLEDREFRESH[event.type] then
        for i=1,#refreshCallbacks do
          setTimeout(function() refreshCallbacks[i](event) end,0)
        end
      end
    end

    function fibaro.postGeofenceEvent(userId,locationId,geofenceAction)
      __assert_type(userId,"number")
      __assert_type(locationId,"number")
      __assert_type(geofenceAction,"string")
      return api.post("/events/publishEvent/GeofenceEvent",
        {
          deviceId = plugin.mainDeviceId,
          userId	= userId,
          locationId	= locationId,
          geofenceAction = geofenceAction,
          timestamp = os.time()
        })
    end

    function fibaro.postCentralSceneEvent(keyId,keyAttribute)
      local data = {
        type =  "centralSceneEvent",
        source = plugin.mainDeviceId,
        data = { keyAttribute = keyAttribute, keyId = keyId }
      }
      return api.post("/plugins/publishEvent", data)
    end
  end
} -- sourceTrigger refreshStates

--------------------- Net functions --------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.net={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,_,copy = fibaro.debugFlags,string.format,table.copy
    netSync = { HTTPClient = function(args)
        local self,queue,HTTP,key = {},{},net.HTTPClient(args),0
        local _request
        local function dequeue()
          table.remove(queue,1)
          local v = queue[1]
          if v then 
            --if _debugFlags.netSync then self:debugf("netSync:Pop %s (%s)",v[3],#queue) end
            --setTimeout(function() _request(table.unpack(v)) end,1)
            _request(table.unpack(v))
          end
        end
        _request = function(url,params,_)
          params = copy(params)
          local uerr,usucc = params.error,params.success
          params.error = function(status)
            --if _debugFlags.netSync then self:debugf("netSync:Error %s %s",key,status) end
            dequeue()
            --if params._logErr then self:errorf(" %s:%s",log or "netSync:",tojson(status)) end
            if uerr then uerr(status) end
          end
          params.success = function(status)
            --if _debugFlags.netSync then self:debugf("netSync:Success %s",key) end
            dequeue()
            if usucc then usucc(status) end
          end
          --if _debugFlags.netSync then self:debugf("netSync:Calling %s",key) end
          HTTP:request(url,params)
        end
        function self.request(_,url,parameters)
          key = key+1
          if next(queue) == nil then
            queue[1]='RUN'
            _request(url,parameters,key)
          else 
            --if _debugFlags.netSync then self:debugf("netSync:Push %s",key) end
            queue[#queue+1]={url,parameters,key} 
          end
        end
        return self
      end}
  end
} -- Net functions

--------------------- QA ---------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.qa={ author = "jan@gabrielsson.com", version = '0.4', depends={'base','debug','event'}, 
  init = function()
    local debugFlags,format,copy = fibaro.debugFlags,string.format,table.copy
    function fibaro.restartQA(id)
      __assert_type(id,"number")
      return api.post("/plugins/restart",{deviceId=id or plugin.mainDeviceId})
    end

    function fibaro.getQAVariable(id,name)
      __assert_type(id,"number")
      __assert_type(name,"string")
      local props = (api.get("/devices/"..(id or plugin.mainDeviceId)) or {}).properties or {}
      for _, v in ipairs(props.quickAppVariables or {}) do
        if v.name==name then return v.value end
      end
    end

    function fibaro.setQAVariable(id,name,value)
      __assert_type(id,"number")
      __assert_type(name,"string")
      return fibaro.call(id,"setVariable",name,value)
    end

    function fibaro.getAllQAVariables(id)
      __assert_type(id,"number")
      local props = (api.get("/devices/"..(id or plugin.mainDeviceId)) or {}).properties or {}
      local res = {}
      for _, v in ipairs(props.quickAppVariables or {}) do
        res[v.name]=v.value
      end
      return res
    end

    function fibaro.isQAEnabled(id)
      __assert_type(id,"number")
      local dev = api.get("/devices/"..(id or plugin.mainDeviceId))
      return (dev or {}).enabled
    end

    function fibaro.setQAValue(device, property, value)
      fibaro.call(device, "updateProperty", property, (json.encode(value)))
    end

    function fibaro.enableQA(id,enable)
      __assert_type(id,"number")
      __assert_type(enable,"boolean")
      return api.post("/devices/"..(id or plugin.mainDeviceId),{enabled=enable==true})
    end

    function QuickApp.debug(_,...) fibaro.debug(nil,...) end
    function QuickApp.trace(_,...) fibaro.trace(nil,...) end
    function QuickApp.warning(_,...) fibaro.warning(nil,...) end
    function QuickApp.error(_,...) fibaro.error(nil,...) end
    function QuickApp.debugf(_,...) fibaro.debugf(nil,...) end
    function QuickApp.tracef(_,...) fibaro.tracef(nil,...) end
    function QuickApp.warningf(_,...) fibaro.warningf(nil,...) end
    function QuickApp.errorf(_,...) fibaro.errorf(nil,...) end
    function QuickApp.debug2(_,tl,...) fibaro.debug(tl,...) end
    function QuickApp.trace2(_,tl,...) fibaro.trace(tl,...) end
    function QuickApp.warning2(_,tl,...) fibaro.warning(tl,...) end
    function QuickApp.error2(_,tl,...) fibaro.error(tl,...) end
    function QuickApp.debugf2(_,tl,...) fibaro.debugf(tl,...) end
    function QuickApp.tracef2(_,tl,...) fibaro.tracef(tl,...) end
    function QuickApp.warningf2(_,tl,...) fibaro.warningf(tl,...) end
    function QuickApp.errorf2(_,tl,...) fibaro.errorf(tl,...) end

    for _,f in ipairs({'debugf','tracef','warningf','errorf','debugf2','tracef2','warningf2','errorf2'}) do
      QuickApp[f]=fibaro.protectFun(QuickApp[f],f,2)
    end

-- Like self:updateView but with formatting. Ex self:setView("label","text","Now %d days",days)
    function QuickApp:setView(elm,prop,fmt,...)
      local str = format(fmt,...)
      self:updateView(elm,prop,str)
    end

-- Get view element value. Ex. self:getView("mySlider","value")
    function QuickApp:getView(elm,prop)
      assert(type(elm)=='string' and type(prop)=='string',"Strings expected as arguments")
      local function find(s)
        if type(s) == 'table' then
          if s.name==elm then return s[prop]
          else for _,v in pairs(s) do local r = find(v) if r then return r end end end
        end
      end
      return find(api.get("/plugins/getView?id="..self.id)["$jason"].body.sections)
    end

-- Change name of QA. Note, if name is changed the QA will restart
    function QuickApp:setName(name)
      if self.name ~= name then api.put("/devices/"..self.id,{name=name}) end
      self.name = name
    end

-- Set log text under device icon - optional timeout to clear the message
    function QuickApp:setIconMessage(msg,timeout)
      if self._logTimer then clearTimeout(self._logTimer) self._logTimer=nil end
      self:updateProperty("log", tostring(msg))
      if timeout then 
        self._logTimer=setTimeout(function() self:updateProperty("log",""); self._logTimer=nil end,1000*timeout) 
      end
    end

-- Disable QA. Note, difficult to enable QA...
    function QuickApp:setEnabled(bool)
      local d = __fibaro_get_device(self.id)
      if d.enabled ~= bool then api.put("/devices/"..self.id,{enabled=bool}) end
    end

-- Hide/show QA. Note, if state is changed the QA will restart
    function QuickApp:setVisible(bool) 
      local d = __fibaro_get_device(self.id)
      if d.visible ~= bool then api.put("/devices/"..self.id,{visible=bool}) end
    end

    function QuickApp.post(_,...) return fibaro.post(...) end
    function QuickApp.event(_,...) return fibaro.event(...) end
    function QuickApp.cancel(_,...) return fibaro.cancel(...) end
    function QuickApp.postRemote(_,...) return fibaro.postRemote(...) end
    function QuickApp.publish(_,...) return fibaro.publish(...) end
    function QuickApp.subscribe(_,...) return fibaro.subscribe(...) end

    function QuickApp:setVersion(model,serial,version)
      local m = model..":"..serial.."/"..version
      if __fibaro_get_device_property(self.id,'model') ~= m then
        quickApp:updateProperty('model',m) 
      end
    end

    function fibaro.deleteFile(deviceId,file)
      local name = type(file)=='table' and file.name or file
      return api.delete("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files/"..name)
    end

    function fibaro.updateFile(deviceId,file,content)
      if type(file)=='string' then
        file = {isMain=false,type='lua',isOpen=false,name=file,content=""}
      end
      file.content = type(content)=='string' and content or file.content
      return api.put("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files/"..file.name,file) 
    end

    function fibaro.updateFiles(deviceId,list)
      if #list == 0 then return true end
      return api.put("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files",list) 
    end

    function fibaro.createFile(deviceId,file,content)
      if type(file)=='string' then
        file = {isMain=false,type='lua',isOpen=false,name=file,content=""}
      end
      file.content = type(content)=='string' and content or file.content
      return api.post("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files",file) 
    end

    function fibaro.getFile(deviceId,file)
      local name = type(file)=='table' and file.name or file
      return api.get("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files/"..name) 
    end

    function fibaro.getFiles(deviceId)
      local res,code = api.get("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files")
      return res or {},code
    end

    function fibaro.copyFileFromTo(fileName,deviceFrom,deviceTo)
      deviceTo = deviceTo or plugin.mainDeviceId
      local copyFile = fibaro.getFile(deviceFrom,fileName)
      assert(copyFile,"File doesn't exists")
      fibaro.addFileTo(copyFile.content,fileName,deviceTo)
    end

    function fibaro.addFileTo(fileContent,fileName,deviceId)
      deviceId = deviceId or plugin.mainDeviceId
      local file = fibaro.getFile(deviceId,fileName)
      if not file then
        local _,res = fibaro.createFile(deviceId,{   -- Create new file
            name=fileName,
            type="lua",
            isMain=false,
            isOpen=false,
            content=fileContent
          })
        if res == 200 then
          fibaro.debug(nil,"File '",fileName,"' added")
        else quickApp:error("Error:",res) end
      elseif file.content ~= fileContent then
        local _,res = fibaro.updateFile(deviceId,{   -- Update existing file
            name=file.name,
            type="lua",
            isMain=file.isMain,
            isOpen=file.isOpen,
            content=fileContent
          })
        if res == 200 then
          fibaro.debug(nil,"File '",fileName,"' updated")
        else fibaro.error(nil,"Error:",res) end
      else
        fibaro.debug(nil,"File '",fileName,"' not changed")
      end
    end

    function fibaro.getFQA(deviceId) return api.get("/quickApp/export/"..deviceId) end

    function fibaro.putFQA(content) -- Should be .fqa json
      if type(content)=='table' then content = json.encode(content) end
      return api.post("/quickApp/",content)
    end

-- Add interfaces to QA. Note, if interfaces are added the QA will restart
function QuickApp:addInterfaces(interfaces)
  assert(type(interfaces) == "table")
  local d, map, i2, res = __fibaro_get_device(self.id), {}, {}, {}
  for _, i in ipairs(d.interfaces or {}) do map[i] = true end
  for _, i in ipairs(interfaces) do i2[i] = true end
  for j, _ in pairs(i2) do if map[j] then i2[j]=nil end end
  for j,_ in pairs(i2) do res[#res+1]=j end
  --print("EX:",json.encode(i2))
  if res[1] then
    api.post("/plugins/interfaces", { action = 'add', deviceId = self.id, interfaces = res })
  end
end

    local _updateProperty = QuickApp.updateProperty
    function QuickApp:updateProperty(prop,value)
      local _props = self.properties
      if _props==nil or _props[prop] ~= nil then
        return _updateProperty(self,prop,value)
      elseif debugFlags.propWarn then self:warningf("Trying to update non-existing property - %s",prop) end
    end

    function QuickApp.setChildIconPath(_,childId,path)
      api.put("/devices/"..childId,{properties={icon={path=path}}})
    end

--Ex. self:callChildren("method",1,2) will call MyClass:method(1,2)
    function QuickApp:callChildren(method,...)
      for _,child in pairs(self.childDevices or {}) do 
        if child[method] then 
          local stat,res = pcall(child[method],child,...)  
          if not stat then self:debug(res,2) end
        end
      end
    end

    function QuickApp:removeAllChildren()
      for id,_ in pairs(self.childDevices or {}) do self:removeChildDevice(id) end
    end

    function QuickApp:numberOfChildren()
      local n = 0
      for _,_ in pairs(self.childDevices or {}) do n=n+1 end
      return n
    end

    function QuickApp.getChildVariable(_,child,varName) 
      for _,v in ipairs(child.properties.quickAppVariables or {}) do
        if v.name==varName then return v.value end
      end
      return ""
    end

    local function annotateClass(self,classObj)
      if not classObj then return end
      local stat,res = pcall(function() return classObj._annotated end) 
      if stat and res then return end
      --self:debug("Annotating class")
      for _,m in ipairs({
          "notify","setVisible","setEnabled","setIconMessage","setName","getView","updateProperty",
          "setView","debug","trace","error","warning","debugf","tracef","errorf","warningf"}) 
      do classObj[m] = self[m] end
      classObj.debugFlags = self.debugFlags
    end

    local function setCallbacks(obj,callbacks)
      if callbacks =="" then return end
      local cbs = {}
      for _,cb in ipairs(callbacks or {}) do
        cbs[cb.name]=cbs[cb.name] or {}
        cbs[cb.name][cb.eventType] = cb.callback
      end
      obj.uiCallbacks = cbs
    end

--[[
  QuickApp:createChild{
    className = "MyChildDevice",      -- class name of child object
    name = "MyName",                  -- Name of child device
    type = "com.fibaro.binarySwitch", -- Type of child device
    properties = {},                  -- Initial properties
    interfaces = {},                  -- Initial interfaces
  }
--]]
    function QuickApp:createChild(args)
      local className = args.className or "QuickAppChild"
      annotateClass(self,_G[className])
      local name = args.name or "Child"
      local tpe = args.type or "com.fibaro.binarySensor"
      local properties = args.properties or {}
      local interfaces = args.interfaces or {}
      properties.quickAppVariables = properties.quickAppVariables or {}
      local function addVar(n,v) table.insert(properties.quickAppVariables,1,{name=n,value=v}) end
      for n,v in pairs(args.quickVars or {}) do addVar(n,v) end
      local callbacks = properties.uiCallbacks
      if  callbacks then 
        callbacks = copy(callbacks)
        addVar('_callbacks',callbacks)
      end
      -- Save class name so we know when we load it next time
      addVar('className',className) -- Add first
      local child = self:createChildDevice({
          name = name,
          type=tpe,
          initialProperties = properties,
          initialInterfaces = interfaces
        },
        _G[className] -- Fetch class constructor from class name
      )
      if callbacks then setCallbacks(child,callbacks) end
      return child
    end

-- Loads all children, called automatically at startup
    function QuickApp:loadChildren()
      local cdevs,n = api.get("/devices?parentId="..self.id) or {},0 -- Pick up all my children
      function self.initChildDevices() end -- Null function, else Fibaro calls it after onInit()...
      for _,child in ipairs(cdevs or {}) do
        if not self.childDevices[child.id] then
          local className = self:getChildVariable(child,"className")
          local callbacks = self:getChildVariable(child,"_callbacks")
          annotateClass(self,_G[className])
          local childObject = _G[className] and _G[className](child) or QuickAppChild(child)
          self.childDevices[child.id]=childObject
          childObject.parent = self
          setCallbacks(childObject,callbacks)
        end
        n=n+1
      end
      return n
    end

    local orgRemoveChildDevice = QuickApp.removeChildDevice
    local childRemovedHook
    function QuickApp:removeChildDevice(id)
      if childRemovedHook then
        pcall(childRemovedHook,id)
      end
      return orgRemoveChildDevice(self,id)
    end
    function QuickApp.setChildRemovedHook(_,fun) childRemovedHook=fun end

    do
      local refs = {}
      function QuickApp.INTERACTIVE_OK_BUTTON(_,ref)
        ref,refs[ref]=refs[ref],nil
        if ref then ref(true) end
      end

      function QuickApp:pushYesNo(mobileId,title,message,callback,timeout)
        local ref = fibaro._orgToString({}):match("%s(.*)")
        api.post("/mobile/push", 
          {
            category = "YES_NO", 
            title = title, 
            message = message, 
            service = "Device", 
            data = {
              actionName = "INTERACTIVE_OK_BUTTON", 
              deviceId = self.id, 
              args = {ref}
            }, 
            action = "RunAction", 
            mobileDevices = { mobileId }, 
          })
        timeout = timeout or (20*60)
        local timer = setTimeout(function()
            local r
            r,refs[ref] = refs[ref],nil
            if r then r(false) end 
          end, 
          timeout*1000)
        refs[ref]=function(val) clearTimeout(timer) callback(val) end
      end
    end
-- UI handler to pass button clicks to children
    function QuickApp:UIHandler(event)
      local obj = self
      if self.id ~= event.deviceId then obj = (self.childDevices or {})[event.deviceId] end
      if not obj then return end
      local elm,etyp = event.elementName, event.eventType
      local cb = obj.uiCallbacks or {}
      if obj[elm] then return obj:callAction(elm, event) end
      if cb[elm] and cb[elm][etyp] and obj[cb[elm][etyp]] then return obj:callAction(cb[elm][etyp], event) end
      if obj[elm.."Clicked"] then return obj:callAction(elm.."Clicked", event) end
      self:warning("UI callback for element:", elm, " not found.")
    end
  end
} -- QA

--------------------- QuickerAppChild --------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.quickerChild={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,format,copy = fibaro.debugFlags,string.format,table.copy
    class 'QuickerAppChild'(QuickAppBase)

    local childDevices={}
    local uidMap={}
    local classNames = {}
    local devices=nil
    local function setCallbacks(obj,callbacks)
      if callbacks =="" then return end
      local cbs = {}
      for _,cb in ipairs(callbacks or {}) do
        cbs[cb.name]=cbs[cb.name] or {}
        cbs[cb.name][cb.eventType] = cb.callback
      end
      obj.uiCallbacks = cbs
    end
    local function annotateClass(self,classObj)
      if not classObj then return end
      local stat,res = pcall(function() return classObj._annotated end) 
      if stat and res then return end
      --self:debug("Annotating class")
      for _,m in ipairs({
          "notify","setVisible","setEnabled","setIconMessage","setName","getView","updateProperty",
          "setView","debug","trace","error","warning","debugf","tracef","errorf","warningf"}) 
      do classObj[m] = self[m] end
      classObj.debugFlags = self.debugFlags
    end
    local function getVar(d,var) -- Lookup quickAppVariable from child's property
      for _,v in ipairs(d.properties.quickAppVariables or {}) do
        if v.name==var then return v.value end
      end
    end

    local function getClassName(f)  -- Get name of class defining __init function
      if classNames[f] then return classNames[f] end -- Cache found names
      for n,v in pairs(_G) do
        pcall(function()
            if type(v)=='userdata' and v.__init == f then
              classNames[f]=n
            end
          end)
        if classNames[f] then 
          return classNames[f] 
        end
      end
    end

    function QuickApp:initChildDevices()
      self.childDevices = childDevices   -- Set QuickApp's self.childDevices to loaded children
      self.uidMap = uidMap
    end

    function QuickerAppChild:__init(args)
      assert(args.uid,"QuickerAppChild missing uid")
      if uidMap[args.uid] then
        if not args.silent then fibaro.warning(__TAG,"Child devices "..args.uid.." already exists") end
        return uidMap[args.uid],false
      end
      local props,created,dev,res={},false,nil,nil
      args.className = args.className or getClassName(self.__init) 
      if devices == nil then
        devices = api.get("/devices?parentId="..plugin.mainDeviceId) or {}
      end
      for _,d in ipairs(devices) do
        if getVar(d,"_UID") == args.uid then
          dev = d
          fibaro.trace(__TAG,"Found existing child:"..dev.id)
          break
        end
      end
      local callbacks
      if not dev then
        assert(args.type,"QuickerAppChild missing type")
        assert(args.name,"QuickerAppChild missing name")
        props.parentId = plugin.mainDeviceId
        props.name = args.name
        props.type = args.type
        local properties = args.properties or {}
        args.quickVars = args.quickVars or {}
        local qvars = properties.quickAppVariables or {}
        qvars[#qvars+1]={name="_UID", value=args.uid }--, type='password'}
        qvars[#qvars+1]={name="_className", value=args.className }--, type='password'}
        callbacks = properties.uiCallbacks
        if  callbacks then 
          callbacks = copy(callbacks)
          args.quickVars['_callbacks']=callbacks
        end
        for k,v in pairs(args.quickVars) do qvars[#qvars+1] = {name=k, value=v} end
        properties.quickAppVariables = qvars
        props.initialProperties = properties
        props.initialInterfaces = args.interfaces or {}
        table.insert(props.initialInterfaces,'quickAppChild')
        dev,res = api.post("/plugins/createChildDevice",props)
        if res~=200 then
          error("Can't create child device "..tostring(res).." - "..json.encode(props))
        end
        created = true
        devices = devices or {}
        devices[#devices+1]=dev
        if callbacks then setCallbacks(self,callbacks) end
        fibaro.trace(__TAG,format("Created new child:%s %s",dev.id,dev.type))
      else
        callbacks = getVar(dev,"_callbacks")
      end
      self.uid = args.uid
      if callbacks then setCallbacks(self,callbacks) end
      uidMap[args.uid]=self
      childDevices[dev.id]=self
      QuickAppBase.__init(self,dev) -- Now when everything is done, call base class initiliser...
      self.parent = quickApp
      return dev,created 
    end

    function QuickApp:loadQuickerChildren(silent,verifier)
      for _,d in ipairs(api.get("/devices?parentId="..plugin.mainDeviceId) or {}) do
        local uid,flag = getVar(d,'_UID'),true
        local className = getVar(d,'_className')
        if verifier then flag = verifier(d,uid,className) end
        if flag then
          annotateClass(self,_G[className])
          d.uid,d.silent = uid,silent==true
          _G[className](d)
        end
      end
    end
  end
} -- QuickerAppChild

--------------------- RPC --------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.rpc={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local var,cid,n = "RPC"..plugin.mainDeviceId,plugin.mainDeviceId,0
    local vinit,path = { name=var, value=""},"/plugins/"..cid.."/variables/"..var
    api.post("/plugins/"..cid.."/variables",{ name=var, value=""}) -- create var if not exist
    function fibaro._rpc(id,fun,args,timeout,qaf)
      n = n + 1
      api.put(path,vinit)
      fibaro.call(id,"RPC_CALL",path,var,n,fun,args,qaf)
      timeout = os.time()+(timeout or 3)
      while os.time() < timeout do
        local r,_ = api.get(path)
        if r and r.value~="" then
          r = r.value 
          if r[1] == n then
            if not r[2] then error(r[3],3) else return select(3,table.unpack(r)) end
          end
        end 
      end
      error(string.format("RPC timeout %s:%d",fun,id),3)
    end
    function fibaro.rpc(id,name,timeout) return function(...) return fibaro._rpc(id,name,{...},timeout) end end
    function QuickApp:RPC_CALL(path2,var2,n2,fun,args,qaf)
      local res
      if qaf then res = {n2,pcall(self[fun],self,table.unpack(args))}
      else res = {n2,pcall(_G[fun],table.unpack(args))} end
      api.put(path2,{name=var2, value=res}) 
    end
--local foo = fibaro.rpc(801,"foo")
--function QuickApp:onInit()
--    self:debug("onInit")
--    for i=1,100 do
--      foo(i,3) -- call QA 972, function foo, arguments 3,i and a timeout of 3s
--    end
--end
  end
} -- RPC

--------------------- Events --------------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.event={ author = "jan@gabrielsson.com", version = '0.4', depends={'base','time'},
  init = function()
    local debugFlags,format,equal,copy,toTime = fibaro.debugFlags,string.format,table.equal,table.copy,fibaro.toTime
  
--  local function DEBUG(...) if debugFlags.event then fibaro.debugf(nil,...) end end

    local em,handlers = { sections = {}, stats={tried=0,matched=0}},{}
    em.BREAK, em.TIMER, em.RULE = '%%BREAK%%', '%%TIMER%%', '%%RULE%%'
    em._handlers = handlers
    local handleEvent,invokeHandler
    local function isEvent(e) return type(e)=='table' and e.type end
    local function isRule(e) return type(e)=='table' and e[em.RULE] end

-- This can be used to "post" an event into this QA... Ex. fibaro.call(ID,'RECIEVE_EVENT',{type='myEvent'})
    function QuickApp.RECIEVE_EVENT(_,ev)
      assert(isEvent(ev),"Bad argument to remote event")
      local time = ev.ev._time
      ev,ev.ev._time = ev.ev,nil
      if time and time+5 < os.time() then fibaro.warning(__TAG,format("Slow events %s, %ss",tostring(ev),os.time()-time)) end
      fibaro.post(ev)
    end

    function fibaro.postRemote(uuid,id,ev)
      if ev == nil then
        id,ev = uuid,id
        assert(tonumber(id) and isEvent(ev),"Bad argument to postRemote")
        ev._from,ev._time = plugin.mainDeviceId,os.time()
        fibaro.call(id,'RECIEVE_EVENT',{type='EVENT',ev=ev}) -- We need this as the system converts "99" to 99 and other "helpful" conversions
      else
        -- post to slave box in the future
      end
    end

    local function post(ev,t,log,hook,customLog)
      local now = os.time()
      t = type(t)=='string' and toTime(t) or t or 0
      if t < 0 then return elseif t < now then t = t+now end
      if debugFlags.post and (type(ev)=='function' or not ev._sh) then 
        (customLog or fibaro.trace)(__TAG,format("Posting %s at %s %s",tostring(ev),os.date("%c",t),type(log)=='string' and ("("..log..")") or "")) end
      if type(ev) == 'function' then
        return setTimeout(function() ev(ev) end,1000*(t-now),log),t
      elseif isEvent(ev) then
        return setTimeout(function() if hook then hook() end handleEvent(ev) end,1000*(t-now),log),t
      else
        error("post(...) not event or function;"..tostring(ev))
      end
    end
    fibaro.post = post 

-- Cancel post in the future
    function fibaro.cancel(ref) clearTimeout(ref) end

    local function transform(obj,tf)
      if type(obj) == 'table' then
        local res = {} for l,v in pairs(obj) do res[l] = transform(v,tf) end 
        return res
      else return tf(obj) end
    end
    fibaro.utils.transform = transform

    local function coerce(x,y) local x1 = tonumber(x) if x1 then return x1,tonumber(y) else return x,y end end
    local constraints = {}
    constraints['=='] = function(val) return function(x) x,val=coerce(x,val) return x == val end end
    constraints['<>'] = function(val) return function(x) return tostring(x):match(val) end end
    constraints['>='] = function(val) return function(x) x,val=coerce(x,val) return x >= val end end
    constraints['<='] = function(val) return function(x) x,val=coerce(x,val) return x <= val end end
    constraints['>'] = function(val) return function(x) x,val=coerce(x,val) return x > val end end
    constraints['<'] = function(val) return function(x) x,val=coerce(x,val) return x < val end end
    constraints['~='] = function(val) return function(x) x,val=coerce(x,val) return x ~= val end end
    constraints[''] = function(_) return function(x) return x ~= nil end end
    em.coerce = coerce

    local function compilePattern2(pattern)
      if type(pattern) == 'table' then
        if pattern._var_ then return end
        for k,v in pairs(pattern) do
          if type(v) == 'string' and v:sub(1,1) == '$' then
            local var,op,val = v:match("$([%w_]*)([<>=~]*)(.*)")
            var = var =="" and "_" or var
            local c = constraints[op](tonumber(val) or val)
            pattern[k] = {_var_=var, _constr=c, _str=v}
          else compilePattern2(v) end
        end
      end
      return pattern
    end

    local function compilePattern(pattern)
      pattern = compilePattern2(copy(pattern))
      if pattern.type and type(pattern.id)=='table' and not pattern.id._constr then
        local m = {}; for _,id in ipairs(pattern.id) do m[id]=true end
        pattern.id = {_var_='_', _constr=function(val) return m[val] end, _str=pattern.id}
      end
      return pattern
    end
    em.compilePattern = compilePattern

    local function match(pattern0, expr0)
      local matches = {}
      local function unify(pattern,expr)
        if pattern == expr then return true
        elseif type(pattern) == 'table' then
          if pattern._var_ then
            local var, constr = pattern._var_, pattern._constr
            if var == '_' then return constr(expr)
            elseif matches[var] then return constr(expr) and unify(matches[var],expr) -- Hmm, equal?
            else matches[var] = expr return constr(expr) end
          end
          if type(expr) ~= "table" then return false end
          for k,v in pairs(pattern) do if not unify(v,expr[k]) then return false end end
          return true
        else return false end
      end
      return unify(pattern0,expr0) and matches or false
    end
    em.match = match

    function invokeHandler(env)
      local t = os.time()
      env.last,env.rule.time = t-(env.rule.time or 0),t
      local status, res = pcall(env.rule.action,env) -- call the associated action
      if not status then
        if type(res)=='string' and not debugFlags.extendedErrors then res = res:gsub("(%[.-%]:%d+:)","") end
        fibaro.errorf(nil,"in %s: %s",env.rule.doc,res)
        env.rule._disabled = true -- disable rule to not generate more errors
        em.stats.errors=(em.stats.errors or 0)+1
      else return res end
    end

    local toHash,fromHash={},{}
    fromHash['device'] = function(e) return {"device"..e.id..e.property,"device"..e.id,"device"..e.property,"device"} end
    fromHash['global-variable'] = function(e) return {'global-variable'..e.name,'global-variable'} end
    fromHash['quickvar'] = function(e) return {"quickvar"..e.id..e.name,"quickvar"..e.id,"quickvar"..e.name,"quickvar"} end
    fromHash['profile'] = function(e) return {'profile'..e.property,'profile'} end
    fromHash['weather'] = function(e) return {'weather'..e.property,'weather'} end
    fromHash['custom-event'] = function(e) return {'custom-event'..e.name,'custom-event'} end
    fromHash['deviceEvent'] = function(e) return {"deviceEvent"..e.id..e.value,"deviceEvent"..e.id,"deviceEvent"..e.value,"deviceEvent"} end
    fromHash['sceneEvent'] = function(e) return {"sceneEvent"..e.id..e.value,"sceneEvent"..e.id,"sceneEvent"..e.value,"sceneEvent"} end
    toHash['device'] = function(e) return "device"..(e.id or "")..(e.property or "") end   

    toHash['global-variable'] = function(e) return 'global-variable'..(e.name or "") end
    toHash['quickvar'] = function(e) return 'quickvar'..(e.id or "")..(e.name or "") end
    toHash['profile'] = function(e) return 'profile'..(e.property or "") end
    toHash['weather'] = function(e) return 'weather'..(e.property or "") end
    toHash['custom-event'] = function(e) return 'custom-event'..(e.name or "") end
    toHash['deviceEvent'] = function(e) return 'deviceEvent'..(e.id or "")..(e.value or "") end
    toHash['sceneEvent'] = function(e) return 'sceneEvent'..(e.id or "")..(e.value or "") end

    local function comboToStr(r)
      local res = { r.doc }
      for _,s in ipairs(r.subs) do res[#res+1]="   "..tostring(s) end
      return table.concat(res,"\n")
    end
    local function rule2str(rule) return rule.doc end

    local function map(f,l,s) s = s or 1; local r={} for i=s,table.maxn(l) do r[#r+1] = f(l[i]) end return r end
    local function mapF(f,l,s) s = s or 1; local e=true for i=s,table.maxn(l) do e = f(l[i]) end return e end

    local function comboEvent(e,action,rl,doc)
      local rm = {[em.RULE]=e, action=action, doc=doc, subs=rl}
      rm.enable = function() mapF(function(e0) e0.enable() end,rl) return rm end
      rm.disable = function() mapF(function(e0) e0.disable() end,rl) return rm end
      rm.tag = function(t) mapF(function(e0) e0.tag(t) end,rl) return rm end
      rm.start = function(event) invokeHandler({rule=rm,event=event}) return rm end
      rm.__tostring = comboToStr
      return rm
    end

    local registered 
    function fibaro.event(pattern,fun,doc)
      if fibaro.registerSourceTriggerCallback and not registered then registered=true fibaro.registerSourceTriggerCallback(handleEvent) end
      doc = doc or format("Event(%s) => ..",json.encodeFast and json.encodeFast(pattern) or json.encode(pattern))
      if type(pattern) == 'table' and pattern[1] then 
        return comboEvent(pattern,fun,map(function(es) return fibaro.event(es,fun) end,pattern),doc) 
      end
      if isEvent(pattern) then
        if pattern.type=='device' and pattern.id and type(pattern.id)=='table' then
          return fibaro.event(map(function(id) local e1 = copy(pattern); e1.id=id return e1 end,pattern.id),fun,doc)
        end
      else error("Bad event pattern, needs .type field") end
      assert(type(fun)=='function',"Second argument must be Lua function")
      local cpattern = compilePattern(pattern)
      local hashKey = toHash[pattern.type] and toHash[pattern.type](pattern) or pattern.type
      handlers[hashKey] = handlers[hashKey] or {}
      local rules = handlers[hashKey]
      local rule,fn = {[em.RULE]=cpattern, event=pattern, action=fun, doc=doc}, true
      for _,rs in ipairs(rules) do -- Collect handlers with identical patterns. {{e1,e2,e3},{e1,e2,e3}}
        if equal(cpattern,rs[1].event) then 
          rs[#rs+1] = rule
          fn = false break 
        end
      end
      if fn then rules[#rules+1] = {rule} end
      rule.enable = function() rule._disabled = nil fibaro.post({type='ruleEnable',rule=rule,_sh=true}) return rule end
      rule.disable = function() rule._disabled = true fibaro.post({type='ruleDisable',rule=rule,_sh=true}) return rule end
      rule.start = function(event) invokeHandler({rule=rule, event=event, p={}}) return rule end
      rule.tag = function(t) rule._tag = t or __TAG; return rule end
      rule.__tostring = rule2str
      if em.SECTION then
        local s = em.sections[em.SECTION] or {}
        s[#s+1] = rule
        em.sections[em.SECTION] = s
      end
      if em.TAG then rule._tag = em.TAG end
      return rule
    end

    function fibaro.removeEvent(pattern,fun)
      local hashKey = toHash[pattern.type] and toHash[pattern.type](pattern) or pattern.type
      local rules,i,j= handlers[hashKey] or {},1,1
      while j <= #rules do
        local rs = rules[j]
        while i <= #rs do
          if rs[i].action==fun then
            table.remove(rs,i)
          else i=i+i end
        end
        if #rs==0 then table.remove(rules,j) else j=j+1 end
      end
    end

    local function ruleHandler2string(e)
      return format("%s => %s",tostring(e.event),tostring(e.rule))
    end

    function handleEvent(ev)
      local hasKeys = fromHash[ev.type] and fromHash[ev.type](ev) or {ev.type}
      for _,hashKey in ipairs(hasKeys) do
        for _,rules in ipairs(handlers[hashKey] or {}) do -- Check all rules of 'type'
          local i,m=1,nil
          em.stats.tried=em.stats.tried+1
          for j=1,#rules do
            if not rules[j]._disabled then    -- find first enabled rule, among rules with same head
              m = match(rules[i][em.RULE],ev) -- and match against that rule
              break
            end
          end
          if m then                           -- we have a match
            for j=i,#rules do                 -- executes all rules with same head
              local rule=rules[j]
              if not rule._disabled then 
                em.stats.matched=em.stats.matched+1
                if invokeHandler({event = ev, p=m, rule=rule, __tostring=ruleHandler2string}) == em.BREAK then return end
              end
            end
          end
        end
      end
    end

    local function handlerEnable(t,handle)
      if type(handle) == 'string' then table.mapf(em[t],em.sections[handle] or {})
      elseif isRule(handle) then handle[t]()
      elseif type(handle) == 'table' then table.mapf(em[t],handle) 
      else error('Not an event handler') end
      return true
    end

    function em.enable(handle,opt)
      if type(handle)=='string' and opt then 
        for s,e in pairs(em.sections or {}) do 
          if s ~= handle then handlerEnable('disable',e) end
        end
      end
      return handlerEnable('enable',handle) 
    end
    function em.disable(handle) return handlerEnable('disable',handle) end

--[[
  Event.http{url="foo",tag="55",
    headers={},
    timeout=60,
    basicAuthorization = {user="admin",password="admin"}
    checkCertificate=0,
    method="GET"}
--]]

    local basicAuthorization
    function fibaro.HTTPEvent(args)
      if not basicAuthorization then fibaro.loadModule("utilities"); basicAuthorization = fibaro.utils.basicAuthorization end
      local options,url = {},args.url
      options.headers = args.headers or {}
      options.timeout = args.timeout
      options.method = args.method or "GET"
      options.data = args.data or options.data
      options.checkCertificate=options.checkCertificate
      if args.basicAuthorization then 
        options.headers['Authorization'] = 
        basicAuthorization(args.basicAuthorization.user,args.basicAuthorization.password)
      end
      if args.accept then options.headers['Accept'] = args.accept end
      net.HTTPClient():request(url,{
          options = options,
          success=function(resp)
            post({type='HTTPEvent',status=resp.status,data=resp.data,headers=resp.headers,tag=args.tag})
          end,
          error=function(resp)
            post({type='HTTPEvent',result=resp,tag=args.tag})
          end
        })
    end

    function fibaro.trueFor(time,test,action,delay)
      local timers = {}
      if type(delay)=='table' then
        delay = copy(delay)
        delay = delay[1] and delay or {delay}
        assert(isEvent(delay[1]),"4th argument not an event for trueFor(...)")
        local state,ref = false,nil
        local function ac()
          if debugFlags.trueFor then fibaro.debug(nil,"trueFor: action()") end
          if action() then
            state = os.time()+time
            if debugFlags.trueFor then fibaro.debug(nil,"trueFor: rescheduling action()") end
            ref = setTimeout(ac,1000*(state-os.time()))
            timers[1]=ref
          else
            ref = nil
            timers[1]=nil
            state = true 
          end
        end
        local  function check()
          if test() then
            if state == false then
              state=os.time()+time
              if debugFlags.trueFor then fibaro.debug(__TAG,format("trueFor: test() true, running action() in %ss",state-os.time())) end
              ref = setTimeout(ac,1000*(state-os.time()))
              timers[1]=ref
            elseif state == true then
              state = state -- NOP
            end
          else
            if ref then timers[1]=nil ref = clearTimeout(ref) end
            if debugFlags.trueFor then fibaro.debug(__TAG,"trueFor: test() false, cancelling action()") end
            state=false
          end
        end
        for _,e in ipairs(delay) do
          fibaro.event(e,check)
        end
        check()
        return function() 
          if timers[1] then clearTimeout(timers[1]) end
          for _,e in ipairs(delay) do fibaro.removeEvent(e,check) end
        end
      else
        delay = delay or 1000
        local state = false
        local  function loop()
          if test() then
            if state == false then
              state=os.time()+time
            elseif state == true then
              state = state -- NOP
            elseif state <=  os.time() then
              if action() then
                state = os.time()+time
              else
                state = true 
              end
            end
          else
            state=false
          end
          timers[1]=setTimeout(loop,delay)
        end
        loop()
        return function() if timers[1] then clearTimeout(timers[1]) end end 
      end
    end


    em.isEvent,em.isRule,em.comboEvent = isEvent,isRule,comboEvent
    fibaro.EM = em
  end 
} -- Events

--------------------- PubSub ---------------------------------------------------
_MODULES = _MODULES or {} -- Global
_MODULES.pubsub={ author = "jan@gabrielsson.com", version = '0.4', depends={'base','event'},
  init = function()
    local debugFlags,format = fibaro.debugFlags,string.format
    local SUB_VAR = "TPUBSUB"
    local idSubs = {}
    local function DEBUG(...) if debugFlags.pubsub then fibaro.debug(__TAG,format(...)) end end
    local inited,initPubSub,match,compile
    local member,equal,copy = table.member,table.equal,table.copy

    function fibaro.publish(event)
      if not inited then initPubSub(quickApp) end
      assert(type(event)=='table' and event.type,"Not an event")
      local subs = idSubs[event.type] or {}
      for _,e in ipairs(subs) do
        if match(e.pattern,event) then
          for id,_ in pairs(e.ids) do 
            DEBUG("Sending sub QA:%s",id)
            fibaro.call(id,"SUBSCRIPTION",event)
          end
        end
      end
    end

    if QuickApp then -- only subscribe if we are an QuickApp. Scenes can publish
      function fibaro.subscribe(events,handler)
        if not inited then initPubSub(quickApp) end
        if not events[1] then events = {events} end
        local subs = quickApp:getVariable(SUB_VAR)
        if subs == "" then subs = {} end
        for _,e in ipairs(events) do
          assert(type(e)=='table' and e.type,"Not an event")
          if not member(e,subs) then subs[#subs+1]=e end
        end
        DEBUG("Setting subscription")
        quickApp:setVariable(SUB_VAR,subs)
        if handler then
          fibaro.event(events,handler)
        end
      end
    end

--  idSubs = {
--    <type> = { { ids = {... }, event=..., pattern = ... }, ... }
--  }

    function initPubSub(selfv)
      fibaro.loadModule("event")
      DEBUG("Setting up pub/sub")
      inited = true

      match = fibaro.EM.match
      compile = fibaro.EM.compilePattern

      function selfv.SUBSCRIPTION(_,e)
        selfv:post(e)
      end

      local function updateSubscriber(id,events)
        if not idSubs[id] then DEBUG("New subscriber, QA:%s",id) end
        for _,ev in ipairs(events) do
          local subs = idSubs[ev.type] or {}
          for _,s in ipairs(subs) do s.ids[id]=nil end
        end
        for _,ev in ipairs(events) do
          local subs = idSubs[ev.type]
          if subs == nil then
            subs = {}
            idSubs[ev.type]=subs
          end
          for _,e in ipairs(subs) do
            if equal(ev,e.event) then
              e.ids[id]=true
              goto nxt
            end
          end
          subs[#subs+1] = { ids={[id]=true}, event=copy(ev), pattern=compile(ev) }
          ::nxt::
        end
      end

      local function checkVars(id,vars)
        for _,var in ipairs(vars or {}) do 
          if var.name==SUB_VAR then return updateSubscriber(id,var.value) end
        end
      end

-- At startup, check all QAs for subscriptions
      for _,d in ipairs(api.get("/devices?interface=quickApp") or {}) do
        checkVars(d.id,d.properties.quickAppVariables)
      end

      fibaro.event({type='quickvar',name=SUB_VAR},            -- If some QA changes subscription
        function(env) 
          local id = env.event.id
          DEBUG("QA:%s updated quickvar sub",id)
          updateSubscriber(id,env.event.value)       -- update
        end) 

      fibaro.event({type='deviceEvent',value='removed'},      -- If some QA is removed
        function(env) 
          local id = env.event.id
          if id ~= quickApp.id then
            DEBUG("QA:%s removed",id)
            updateSubscriber(env.event.id,{})               -- update
          end
        end)

      fibaro.event({
          {type='deviceEvent',value='created'},              -- If some QA is added or modified
          {type='deviceEvent',value='modified'}
        },
        function(env)                                             -- update
          local id = env.event.id
          if id ~= quickApp.id then
            DEBUG("QA:%s created/modified",id)
            checkVars(id,api.get("/devices/"..id).properties.quickAppVariables)
          end
        end)
    end
  end
} -- PubSub
--------------------------------
if debug then                           -- Embedded call...
  local file = debug.getinfo(1)         -- Find out what file we are
  if file and file.source then
    file = file.source:sub(2)
    local c = io.open(file,"r"):read("*all")
    local path = file:match("(.*/)")
    c:gsub("%-%-%-%-%-+ ([%w]+[ ]?%w*) %-%-%-%-*\n(.-\n)%-%-%-%-",function(s,c)
        local name = c:match("MODULES%.(%w+)=")
        local fname = path.."fibaroExtra_"..name..".lua"
        print("Writing",fname)
        local f = io.open(fname,"w+")
        assert(f,"Can't open "..fname)
        f:write(c)
        f:close()
      end)
  end
end