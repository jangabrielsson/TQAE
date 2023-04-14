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

