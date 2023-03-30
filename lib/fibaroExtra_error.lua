_MODULES = _MODULES or {} -- Global
_MODULES.error={ author = "jan@gabrielsson.com", version = '0.4', init = function()
    json = json or {}
    local debugFlags,format,copy = fibaro.debugFlags,string.format,table.copy
    local setinterval,encode,decode =  setInterval, json.encode, json.decode -- gives us a better error messages
    local oldClearTimout,oldSetTimout

    if  hc3_emulator then
      setTimeout,oldSetTimout=function(f,...)
        local t
        local function nf(...)
          if t._prehook then t._prehook() end
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

