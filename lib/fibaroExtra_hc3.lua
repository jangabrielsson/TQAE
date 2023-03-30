_MODULES = _MODULES or {} -- Global
_MODULES.hc3={ author = "jan@gabrielsson.com", version = '0.4', init = function()
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

