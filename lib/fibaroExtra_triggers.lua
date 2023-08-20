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

