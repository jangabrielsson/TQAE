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

