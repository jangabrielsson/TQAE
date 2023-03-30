_MODULES = _MODULES or {} -- Global
_MODULES.globals={ author = "jan@gabrielsson.com", version = '0.4', init = function()
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

