_MODULES = _MODULES or {} -- Global
_MODULES.customEvents={ author = "jan@gabrielsson.com", version = '0.41', init = function()
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

