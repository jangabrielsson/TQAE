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

