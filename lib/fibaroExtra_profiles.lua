_MODULES = _MODULES or {} -- Global
_MODULES.profiles={ author = "jan@gabrielsson.com", version = '0.4', init = function()
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

