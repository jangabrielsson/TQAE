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

    fibaro.ALARM_INTERVAL = 1000
    local fun
    local ref
    local armedPs={}
    local function watchAlarms()
      for _,p in ipairs(api.get("/alarms/v1/partitions") or {}) do
        if p.secondsToArm and not armedPs[p.id] then
          setTimeout(function() pcall(fun,p.id,p.secondsToArm) end,0)
        end
        armedPs[p.id] = p.secondsToArm
      end
    end
    function fibaro.activatedPartitions(callback)
      __assert_type(callback,"function")
      fun = callback
      if fun and ref == nil then
        ref = setInterval(watchAlarms,fibaro.ALARM_INTERVAL)
      elseif fun == nil and ref then
        clearInterval(ref); ref = nil 
      end
    end

    function fibaro.activatedPartitionsEvents()
      fibaro.activatedPartitions(function(id,secs)
          fibaro._postSourceTrigger({type='alarm',property='activated',id=id,seconds=secs})
        end)
    end

--[[ Ex. check what partitions have breached devices
for _,p in ipairs(getAllPartitions()) do
  local bd = getBreachedDevicesInPartition(p)
  if bd[1] then print("Partition "..p.." contains breached devices "..json.encode(bd)) end
end
--]]
  end
} -- Alarm

