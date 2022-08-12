--[[
                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.
 --]]

-- luacheck: globals ignore quickApp plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator HUEv2Engine fibaro
-- luacheck: ignore 212/self

local version = 0.3

HUEv2Engine = HUEv2Engine or {}
HUEv2Engine.version = version
local DEBUG,WARNING,ERROR,TRACE
fibaro.hue = fibaro.hue or {}
fibaro.hue.Engine = HUEv2Engine
local function setup()
  DEBUG,WARNING,ERROR,TRACE=fibaro.hue.DEBUG,fibaro.hue.WARNING,fibaro.hue.ERROR,fibaro.hue.TRACE
end


--[[
debug.info          -- greetings etc
debug.class         -- class creation
debug.resource_mgmt -- creation/delation/modification of object
debug.event         -- incoming event from Hue hub
debug.v2api         -- v2api info (unhandled events etc)
debug.call          -- http calls to Hue hub
debug.unknownType   -- Unhandled device updates
debug.logger        -- Logs subscribption events
--]]

--[[
Room--+
      |             +------ Service A
      |             |
      +---Device ---+
                    |
                 +--+------ Service B
                 |
Zone-------------+
                 |
                 +----- Service - Grouped Light
--]]

local _initEngine
local function main()
  local v2 = "1948086000"
  local OPTIMISTIC = false
  local err_retry = 3
  local utils,post = fibaro.utils,fibaro.post
  local resources = {}
  local props,meths={},{}
  local hueGET,huePUT
  local app_key,url,callBack
  local fmt = string.format
  local merge = utils.keyMerge
  local function createResourceTable()
    local self = { resources={}, id2resource={} }
    local resources,id2resource = self.resources,self.id2resource
    function self.add(id,rsrc)
      local typ = rsrc.type
      if id2resource[id] then self.modify(id,rsrc)
      else
        if _G[typ] then
          rsrc = _G[typ](rsrc)
        else
          quickApp:warningf("Missing resource type:%s",typ)
          return
        end
        resources[typ]=resources[typ] or {}; 
        resources[typ][id]=rsrc; 
        id2resource[id]=rsrc 
        rsrc:added()
      end
    end
    function self.modify(id,rsrc)
      assert(id2resource[id],"No resource for modify") 
      id2resource[id]:modify(rsrc)
    end
    function self.delete(id) 
      local rsrc=id2resource[id]
      assert(rsrc,"No resource") 
      resources[rsrc.type][id]=nil
      rsrc:deleted()
      id2resource[id]=nil 
    end
    function self.get(id) return id2resource[id] end
    return self
  end

  local function resolve(rr) return rr and resources.get(rr.rid) or {} end

  class 'hueResource'
  function hueResource:__init(rsrc) self:setup(rsrc) end

  function hueResource:setup(rsrc)
    local id = rsrc.id
    self.id = id
    for m,_ in pairs(self._inheritedFuns or {}) do self[m]=nil end
    self.rsrc = rsrc
    self.type = rsrc.type
    self.services = rsrc.services
    self.children = rsrc.children
    self.owner = rsrc.owner
    self.metadata = rsrc.metadata or {}
    self.product_data = rsrc.product_data or {}
    self.resourceType = self.product_data.model_id or self.metadata.archetype or "unknown"
    self.resourceName = self.product_data.product_name
    self.name = self.metadata.name
    self._inheritedFuns = {}
    self.path = "/clip/v2/resource/"..self.type.."/"..self.id
    self._inited = true
    self.listernes = {}
    self._props = props[self.type] 
    self._meths = meths[self.type]
    DEBUG("class","Setup %s '%s' %s",self.id,self.type,self.name or "rsrc")
  end
  function hueResource:getName(dflt)
    if self.name then return self.name end
    local n = resolve(self.owner).name
    if n then self.name = n return n end
    return dflt
  end
  function hueResource:added() DEBUG('resource_mgmt',"Created %s",tostring(self)) end
  function hueResource:deleted() DEBUG('resource_mgmt',"Deleted %s",tostring(self)) end
  function hueResource:modified(rsrc) self:setup(rsrc) DEBUG('resource_mgmt',"Modified %s",tostring(self)) end
  function hueResource:findServiceByType(typ)
    local r = {}
    for _,s in ipairs(self.services or {}) do local x=resolve(s) if x.type==typ then r[#r+1]=x end end
    return r
  end
  function hueResource:getCommand(cmd)
    if self[cmd] then return self end
    for _,s in ipairs(self.services or {}) do 
      local x=resolve(s) 
      if x[cmd] then return x end
    end
  end

  function hueResource:getProps()
    local r = {}
    for _,s in ipairs(self.services or {}) do merge(r,resolve(s):getProps()) end
    merge(r,self._props or {})
    return r
  end
  function hueResource:getMethods()
    local r = {}
    for _,s in ipairs(self.services or {}) do merge(r,resolve(s):getMethods()) end
    merge(r,self._meths or {})
    return r
  end
  function hueResource:event(data)
    DEBUG('event',"Event %s",data)
    if self.update then self:updata(data) return end
    local p = self._props -- { power_state = { get, set changed }, ...
    if p then
      local r = self.rsrc
      for k,f in pairs(p) do
        if data[k] and f.changed then
          local c,v = f.changed(r,data)
          if c then
            f.set(r,v)
            self:publish(k,v)
          end
        end
      end
    end
    if self.owner then
      local o = resolve(self.owner)
      if o._postEvent then o:_postEvent(self.id) end
    end
  end
  function hueResource:publishMySubs()
    local p = self._props -- { power_state = { get, set changed }, ...
    if p then
      local r = self.rsrc
      for k,f in pairs(p) do
        if r[k] then self:publish(k,f.get(r)) end
      end
    end
  end
  function hueResource:publishAll()
    for _,s in ipairs(self.services or {}) do resolve(s):publishMySubs() end
  end
  function hueResource:publish(key,value)
    local ll = self.listernes[key] or {}
    if next(ll) then
      for l,_ in pairs(ll) do
        l(key,value,self)
      end
    end
  end

  function hueResource:subscribe(key,fun)
    if self.services then
      for _,s in ipairs(self.services or {}) do resolve(s):subscribe(key,fun) end
    elseif self._props and self._props[key] then 
      self.listernes[key] = self.listernes[key] or {}
      self.listernes[key][fun]=true
    end
  end
  function hueResource:unsubscribe(key,fun)
    for _,s in ipairs(self.services or {}) do resolve(s):unsubscribe(key,fun) end
    if self.listerners[key] then 
      if fun==true then self.listerners[key]={}
      else self.listerners[key][fun]=nil end
    end
  end
  function hueResource:sendCmd(cmd) return huePUT(self.path,cmd) end
  function hueResource:__tostring() return self._str or fmt("[rsrc:%s]",self.id) end

-------

  class 'homekit'(hueResource)
  function homekit:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[homekit:%s]",self.id)
  end

  class 'device'(hueResource)
  function device:__init(id)
    hueResource.__init(self,id)
    self.archetype = self.rsrc.metadata.archetype
    self.name = self.name or "device"
    self._str = fmt("[device:%s,%s,%s]",self.id,self.name,self.resourceType)
  end

  local pprops = { color={"setColor"},color_temperature={"setTemperature"},dimming={"setDim"} }
  local function pruneLights(self)
    self._props = table.copyShallow(self._props)
    self._meths = table.copyShallow(self._meths)
    for p,m in ipairs(pprops) do
      if self.rsrc[p]==nil then 
        self._props[p]=nil 
        for _,f in ipairs(m) do self._meths[f]=nil end
      end
    end
  end

  class 'light'(hueResource)
  function light:__init(id)
    hueResource.__init(self,id)
    self.archetype = resolve(self.owner).archetype or "unknown_archetype"
    pruneLights(self)
    self._str = fmt("[ligh:%s,%s,%s]",self.id,self:getName("LGHT"),self.resourceType)
  end
  function light:turnOn(transition) self:sendCmd({on={on=true},dynamics=transition and {duration=transition} or nil}) if OPTIMISTIC then self.rsrc.on.on = true end end
  function light:turnOff(transition) self:sendCmd({on={on=false},dynamics=transition and {duration=transition} or nil}) if OPTIMISTIC then self.rsrc.on.on = true end end
  function light:setDim(val,transition)
    if val == -1 then
      self:sendCmd({dimming_delta={action='stop'}})
    else 
      self:sendCmd({dimming={brightness=val},dynamics=transition and {duration=transition} or nil}) 
    end
  end
  function light:setColor(arg,transition) -- {x=x,y=y} <string>, {r=r,g=g,b=b}
    local xy
    if type(arg)=='string' then
      xy = HUEv2Engine.xyColors[tostring(arg:lower())] or HUEv2Engine.xyColors['white']
    elseif type(arg)=='table' then
      if arg.x and arg.y then xy = arg 
      elseif arg.r and arg.g and arg.b then
      end
    end
    if xy then self:sendCmd({color={xy=xy},dynamics=transition and {duration=transition} or nil}) end
  end
  function light:toggle(transition)
    local on = self.rsrc.on.on
    self:sendCmd({on={on=not on},dynamics=transition and {duration=transition} or nil})
    if OPTIMISTIC then self.rsrc.on.on = not on end
  end
  function light:rawCmd(cmd) self:sendCmd(cmd) end
  function light:setTemperature(t,transition) self:sendCmd({color_temperature={mirek=math.floor(t+0.5)},dynamics=transition and {duration=transition} or nil}) end
  meths.light = { turnOn=true, turnOff=true, setDim=true, setColor=true, setTemperature=true, toggle=true, rawCmd=true }
  props.light = {
    on={get=function(r) return r.on.on end,set=function(r,v) r.on.on=v end, changed=function(o,n) return o.on.on ~= n.on.on, n.on.on end },
    dimming={
      get=function(r) return r.dimming.brightness end,
      set=function(r,v) r.dimming.brightness=v end,
      changed=function(o,n) return o.dimming.brightness~=n.dimming.brightness,n.dimming.brightness end,
    },
    color_temperature={
      get=function(r) return r.color_temperature.mirek end,
      set=function(r,v) r.color_temperature.mirek=v end,
      changed=function(o,n) return n.color_temperature.mirek_valid and o.color_temperature.mirek~=n.color_temperature.mirek,n.color_temperature.mirek end,
    },
    color={
      get=function(r) return r.color.xy end,
      set=function(r,v) r.color.xy=v end,
      changed=function(o,n) 
        local oxy,nxy = o.color.xy,n.color.xy
        return oxy.x~=nxy.x or oxy.y~=nxy.y,nxy
      end,
    },
  }

  props.zigbee_connectivity = {
    status={
      get=function(r) return r.status end,
      set=function(r,v) r.status=v end,
      changed=function(o,n) return o.status~=n.status,n.status end,
    },
  }
  class 'zigbee_connectivity'(hueResource)
  function zigbee_connectivity:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[zigbee_connectivity:%s,%s]",self.id,self:getName("CON"))
  end
  function zigbee_connectivity:connected()
    return self.rsrc.status=="connected"
  end

  props.device_power = {
    power_state={
      get=function(r) return r.power_state end,
      set=function(r,v) r.power_state=v end,
      changed=function(o,n) local s0,s1 = o.power_state,n.power_state return s0.battery_state~=s1.battery_state or s0.battery_level~=s1.battery_level,s1  end
    },
  }
  class 'device_power'(hueResource)
  function device_power:__init(id)
    hueResource.__init(self,id)
  end
  function device_power:power()
    return self.rsrc.power_state.battery_level,self.rsrc.power_state.battery_state
  end
  function device_power:__tostring()
    return fmt("[device_power:%s,%s,value:%s]",self.id,self:getName(),self:power())
  end
  function device_power:event(data)
    hueResource.event(self,data)
  end

  props.zgp_connectivity = {
    status={get=function(r) return r.status end,set=function(r,v) r.status=v end},
  }
  meths.zgp_connectivity = { connected=true }
  class 'zgp_connectivity'(hueResource)
  function zgp_connectivity:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[zgp_connectivity:%s,%s]",self.id,self:getName("ZGP"))
  end
  function zgp_connectivity:connected()
    return self.rsrc.status=="connected"
  end

  class 'entertainment'(hueResource)
  function entertainment:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[entertainment:%s,%s]",self.id,self:getName("ENT"))
  end

  class 'entertainment_configuration'(hueResource)
  function entertainment_configuration:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[entertainment_configuration:%s,%s]",self.id,self:getName("ENT_CFG"))
  end

  class 'room'(hueResource)
  function room:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[room:%s,%s,%s]",self.id,self.name,self.resourceType)
  end
  function room:setup(rsrc) hueResource.setup(self,rsrc) self.resourceName="Room" end


  class 'zone'(hueResource)
  function zone:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[zone:%s,%s,%s]",self.id,self.name,self.resourceType)
  end
  function zone:setup(rsrc) hueResource.setup(self,rsrc) self.resourceName="Zone" end

  props.grouped_light = props.light
  meths.grouped_light = meths.light
  class 'grouped_light'(hueResource)
  function grouped_light:__init(id)
    hueResource.__init(self,id)
    pruneLights(self)
  end
  function grouped_light:__tostring() return fmt("[grouped_light:%s,%s]",self.id,self:getName("GROUP")) end
  function grouped_light:turnOn(transition) self:sendCmd({on={on=true},dynamics=transition and {duration=transition} or nil}) if OPTIMISTIC then self.rsrc.on.on = true end end
  function grouped_light:turnOff(transition) self:sendCmd({on={on=false},dynamics=transition and {duration=transition} or nil}) if OPTIMISTIC then self.rsrc.on.on = true end end
  function grouped_light:setDim(val,transition)
    if val == -1 then
      self:sendCmd({dimming_delta={action='stop'}})
    else 
      self:sendCmd({dimming={brightness=val},dynamics=transition and {duration=transition} or nil}) 
    end
  end
  function grouped_light:setColor(arg,transition) -- {x=x,y=y} <string>, {r=r,g=g,b=b}
    local xy
    if type(arg)=='string' then
      xy = HUEv2Engine.xyColors[tostring(arg:lower())] or HUEv2Engine.xyColors['white']
    elseif type(arg)=='table' then
      if arg.x and arg.y then xy = arg 
      elseif arg.r and arg.g and arg.b then
      end
    end
    if xy then self:sendCmd({color={xy=xy},dynamics=transition and {duration=transition} or nil}) end
  end
  function light:toggle(transition)
    local on = self.rsrc.on.on
    self:sendCmd({on={on=not on},dynamics=transition and {duration=transition} or nil})
    if OPTIMISTIC then self.rsrc.on.on = not on end
  end
  function light:rawCmd(cmd) self:sendCmd(cmd) end
  function grouped_light:setTemperature(t,transition) self:sendCmd({color_temperature={mirek=math.floor(t+0.5)},dynamics=transition and {duration=transition} or nil}) end

  meths.scene = { recall=true }
  class 'scene'(hueResource)
  function scene:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[scene:%s,%s]",self.id,self.name)
  end
  function scene:recall(transition) self:sendCmd({recall = { action = "active" },dynamics=transition and {duration=transition} or nil }) end

  props.button = {
    button = {
      get=function(r) return r.button and r.button.last_event end,
      set=function(r,v) if not r.button then r.button = { last_event = v } else r.button.last_event=v end end,
      changed=function(o,n)
        local ob,nb = o.button or {},n.button or {}
        return ob.last_event~=nb.last_event,nb.last_event 
      end
    }
  }
  class 'button'(hueResource)
  function button:__init(id)
    hueResource.__init(self,id)
  end
  function button:button_state()
    return self.rsrc.button and self.rsrc.button.last_event,self.rsrc.metadata.control_id
  end
  function button:__tostring()
    return fmt("[button:%s,%s,value:%s]",self.id,self:getName("BTN"),self:button_state())
  end

  props.temperature = {
    temperature={
      get=function(r) return r.temperature.temperature end,
      set=function(r,v) r.temperature.temperature=v end,
      changed=function(o,n) return o.temperature.temperature~=n.temperature.temperature,n.temperature.temperature end,
    },
  }
  class 'temperature'(hueResource)
  function temperature:__init(id)
    hueResource.__init(self,id)
  end
  function temperature:temperature()
    return self.rsrc.temperature.temperature
  end
  function temperature:__tostring()
    return fmt("[temperature:%s,%s,value:%s]",self.id,self:getName(),self:temperature())
  end

  props.motion = {
    motion={
      get=function(r) return r.motion.motion end,
      set=function(r,v) r.motion.motion=v end,
      changed=function(o,n) return o.motion.motion~=n.motion.motion,n.motion.motion end
    },
  }
  class 'motion'(hueResource)
  function motion:__init(id)
    hueResource.__init(self,id)
  end
  function motion:motion()
    return self.rsrc.motion.motion
  end
  function motion:__tostring()
    return fmt("[motion:%s,%s,value:%s]",self.id,self:getName(),self:motion())
  end

  props.light_level = {
    light={
      get=function(r) return r.light.light_level end,
      set=function(r,v) r.light.light_level=v end,
      changed=function(o,n) return o.light.light_level~=n.light.light_level,n.light.light_level end,
    },
  }
  class 'light_level'(hueResource)
  function light_level:__init(id)
    hueResource.__init(self,id)
  end
  function light_level:light_level()
    return self.rsrc.light.light_level
  end
  function light_level:__tostring()
    return fmt("[light_level:%s,%s,value:%s]",self.id,self:getName(),self:light_level())
  end

  class 'bridge'(hueResource)
  function bridge:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[bridge:%s]",self.id)
  end

  class 'bridge_home'(hueResource)
  function bridge_home:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[bridge_home:%s]",self.id)
  end

  class 'behavior_script'(hueResource)
  function behavior_script:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[behavior_script:%s,%s,%s]",self.id,self.rsrc.metadata.name,self.rsrc.metadata.category)
  end

  class 'behavior_instance'(hueResource)
  function behavior_instance:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[behavior_instance:%s,%s,%s]",self.id,self.rsrc.metadata.name,self.rsrc.metadata.category)
  end

  class 'geolocation'(hueResource)
  function geolocation:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[geolocation:%s]",self.id)
  end

  class 'geofence_client'(hueResource)
  function geofence_client:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[geofence_client:%s]",self.id)
  end

  local function fetchEvents()
    local getw
    local eurl = url.."/eventstream/clip/v2"
    local args = { options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = app_key }}}
    function args.success(res)
      local data = json.decode(res.data)
      for _,e1 in ipairs(data) do
        if e1.type=='update' then
          for _,r in ipairs(e1.data) do
            local d = resources.get(r.id)
            if d and d.event then 
              DEBUG('all_event',"Event id:%s type:%s",d.id,d.type)--,json.encode(e2))
              d:event(r)
            else
              local _ = 0
              if debug.unknownType then WARNING("Unknow resource type: %s",json.encode(e1)) end
            end
          end
        elseif e1.type == 'delete' then
          for _,r in ipairs(e1.data) do
            resources.delete(r.id)
          end
        elseif e1.type == 'add' then
          for _,r in ipairs(e1.data) do
            resources.add(r.id,r)
          end
        else
          DEBUG('v2api',"New v2 event type: %s",e1.type)
          DEBUG('v2api',"%s",json.encode(e1))
        end
      end
      getw()
    end
    function args.error(err) if err~="timeout" and err~="wantread" then ERROR("/eventstream: %s",err) end getw() end
    function getw() net.HTTPClient():request(eurl,args) end
    setTimeout(getw,0)
  end

  function hueGET(api,event) 
    net.HTTPClient():request(url..api,{
        options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = app_key }},
        success = function(res) post({type=event,result=json.decode(res.data)}) end,
        error = function(err) post({type=event,error=err})  end,
      })
  end

  function huePUT(path,data,op)
    DEBUG('call',"%s %s",path,json.encode(data))
    net.HTTPClient():request(url..path,{
        options = { 
          method=op or 'PUT', data=data and json.encode(data) or nil, 
          checkCertificate=false, headers={ ['hue-application-key'] = app_key }
        },
        success = function(resp)  
          local b = resp
        end,
        error = function(err) 
          ERROR("hue call, %s %s - %s",path,json.encode(data),err) 
        end,
      })
  end

--[[
{
"dimming":{"brightness":58.66}, // color,color_temperature,on
"owner":{"rtype":"device","rid":"8dddf049-0a73-44e2-8fdd-e3c2310c1bb1"},
"type":"light",
"id_v1":"/lights/5",
"id":"fb31c148-177b-4b52-a1a5-e02d46c1c3dd"
}

{
"id_v1":"/groups/5",
"type":"grouped_light",
"on":{"on":true},
"id":"39c94b33-7a3d-48e7-8cc1-dc603d401db2"
}

{
"id":"efc3283b-304f-4053-a01a-87d0c51462c3",
"owner":{"rtype":"device","rid":"a007e50b-0bdd-4e48-bee0-97636d57285a"},
"button":{"last_event":"initial_press"}, // "repeat","long_release","short_release"
"id_v1":"/sensors/2",
"type":"button"
}

{
"type":"light_level",
"light":{"light_level":0,"light_level_valid":true},
"owner":{"rtype":"device","rid":"9222ea53-37a6-4ac0-b57d-74bca1cfa23f"},
"id_v1":"/sensors/7",
"id":"a7295dae-379b-4d61-962f-6f9ad9426eda"
}

{
"type":"motion",
"motion":{"motion":false,"motion_valid":true},
"owner":{"rtype":"device","rid":"9222ea53-37a6-4ac0-b57d-74bca1cfa23f"},
"id_v1":"/sensors/6","id":"6356a5c3-e5b7-455c-bf54-3af2ac511fe6"
}

{
"type":"device_power",
"power_state":{"battery_state":"normal","battery_level":76},
"owner":{"rtype":"device","rid":"a007e50b-0bdd-4e48-bee0-97636d57285a"},
"id_v1":"/sensors/2",
"id":"d6bc1f77-4603-4036-ae5f-28b16eefe4b5"
}

{
"type":"zigbee_connectivity",
"owner":{"rtype":"device","rid":"3ab27084-d02f-44b9-bd56-70ea41163cb6"},
"status":"connected",  // "status":"connectivity_issue"
"id_v1":"/lights/9",
"id":"c024b020-395d-45a4-98ce-9df1409eda30"
}
--]]

---------------------------------------------------------------------------

  fibaro.event({type='STARTUP'},function(_) hueGET("/api/config",'HUB_VERSION') end)

  fibaro.event({type='HUB_VERSION'},function(env)
      local ev = env.event
      if ev.error then 
        ERROR("%s",ev.error)
      else
        resources = createResourceTable()
        local res = ev.result
        if res.swversion >= v2 then
          DEBUG('info',"V2 api available (%s)",res.swversion)
          post({type='REFRESH_RESOURCES'})
        else
          WARNING("V2 api not available (%s)",res.swversion)
        end
      end
    end)

  fibaro.event({type='REFRESH_RESOURCES'},function(_) hueGET("/clip/v2/resource",'REFRESHED_RESOURCES') end)

  fibaro.event({type='REFRESHED_RESOURCES'},function(env)
      local ev = env.event
      if ev.error then 
        ERROR("/clip/v2/resource %s",ev.error)
        ERROR("Retry in %ss",err_retry)
        post({type='REFRESH_RESOURCES'},1000*err_retry)
        return
      end
      for _,r in pairs(resources.id2resource) do
        r._dirty = true
      end
      for _,r in ipairs(ev.result.data or {}) do
        r._dirty=nil
        resources.add(r.id,r)
      end
      for _,r in pairs(resources.id2resource) do
        if r._dirty then
          resources.delete(r.id)
        end
      end
      local cb
      if callBack then cb,callBack=callBack,nil setTimeout(cb,0) end
    end)

  function HUEv2Engine:getResources() return resources.resources end
  function HUEv2Engine:getResourceIds() return resources.id2resource end
  function HUEv2Engine:getResource(id) return resources.id2resource[id] end
  function HUEv2Engine:getResourceType(typ) return resources.resources[typ] end

  local filter1 = { device=1, scene=10, room=2, zone=3 }

  local filter2 = { device=1, light=4, button=5, scene=10, room=2, zone=3, temperature=6, light_level=7, motion=8, grouped_light=9, zigbee_connectivity=10, device_power=11 }

  function HUEv2Engine:dumpDeviceTable(filter,selector,orgDevMap)
    filter =filter and filter2 or filter1
    orgDevMap = orgDevMap or {}
    selector = selector or function() return true end
    local  pb = utils.printBuffer("\n")
    pb:add("\nlocal HueDeviceTable = {\n")
    local rs = {}
    for _,r in pairs(HUEv2Engine:getResourceIds()) do
      if filter[r.type] then
        rs[#rs+1]={order=filter[r.type],str=tostring(r),r=r}
      end
    end
    local parentMap = {room={},zone={}}
    for _,r0 in ipairs(rs) do
      local r = r0.r
      if r.type=='room' or r.type=='zone' then
        for _,c in ipairs(r.children) do
          parentMap[r.type][c.rid]=r.name
        end
      end
    end
    table.sort(rs,function(a,b) return a.order < b.order or a.order==b.order and a.str < b.str end) 
    for _,r0 in ipairs(rs) do
      local r = r0.r
      local room = parentMap.room[r.id]
      local zone = parentMap.zone[r.id]
      local ref = (orgDevMap[r.id] or {}).ref
      room=room and (",room='"..room.."'") or ""
      zone=zone and (",zone='"..zone.."'") or ""
      ref=ref and (",ref='"..ref.."'") or ""
      if r.type=='scene' then
        room = (",room='"..resolve(r.rsrc.group).name.."'") 
      end
      pb:printf("%s['%s']={type='%s',name='%s',model='%s'%s%s%s},\n",selector(r.id) and "  " or "--",r.id,r.type,r.name,r.resourceType,room,zone,ref) 
    end
    pb:add("}\n")
    print(pb:tostring())
  end

  function HUEv2Engine:createDeviceTable(filter)
    filter =filter and filter2 or filter1
    local rs,rs2,res = HUEv2Engine:getResourceIds(),{},{}

    local parentMap = {room={},zone={}}
    for uid,r in pairs(rs) do
      if filter[r.type] then
        rs2[uid]=r
        if r.type=='room' or r.type=='zone' then
          for _,c in ipairs(r.children) do
            parentMap[r.type][c.rid]=r.name
          end
        end
      end
    end
    for uid,r in pairs(rs2) do
      local m = {}
      res[uid]=m
      m.room = parentMap.room[r.id]
      m.zone = parentMap.zone[r.id]
      if r.type=='scene' then
        m.room = resolve(r.rsrc.group).name
      end
      m.type=r.type
      m.name=r.name
      m.model=r.resourceType
    end
    return res
  end

  local function sortResources(list,f)
    local rs = {}
    for _,r in pairs(list) do
      r = f and f(r) or r
      if filter2[r.type] then
        rs[#rs+1]={order=filter2[r.type],resource=r}
      end
    end
    table.sort(rs,function(a,b) return a.order < b.order or a.order==b.order and a.resource.id < b.resource.id end) 
    local r0 = {}
    for _,r in ipairs(rs) do r0[#r0+1]=r.resource end
    return r0
  end

  local function printResource(r,pb,ind)
    pb:add(string.rep(' ',ind)..tostring(r).."\n")
    if r.owner then pb:add(string.rep(' ',ind+2).."Parent:"..r.owner.rid.."\n") end
    local rs = r.children and sortResources(r.children,function(r) return resolve(r) end) or {}
    if rs[1] then
      pb:add(string.rep(' ',ind+2).."Children:\n")
      for _,c in ipairs(rs) do
        printResource(c,pb,ind+4)
      end
    end
    rs = r.services and sortResources(r.services,function(r) return resolve(r) end) or {}
    if rs[1] then
      pb:add(string.rep(' ',ind+2).."Services:\n")
      for _,c in ipairs(rs) do
        printResource(c,pb,ind+4)
      end
    end
    if r.rsrc.actions then
      local w = resolve(r.rsrc.group)
      pb:add(string.rep(' ',ind+2).."Group:"..tostring(w).."\n")
      pb:add(string.rep(' ',ind+2).."Targets:\n")
      for _,a in ipairs(r.rsrc.actions or {}) do
        local f = resolve(a.target)
        pb:add(string.rep(' ',ind+4)..tostring(f).."\n")
      end
    end
  end

  function HUEv2Engine:listAllDevicesGrouped(groups)
    local  pb = utils.printBuffer("\n")
    pb:add("------------------------\n")
    local rs = sortResources(HUEv2Engine:getResourceIds())
    for _,r in ipairs(rs) do if not r.owner then printResource(r,pb,0) end end
    pb:add("------------------------\n")
    print(pb:tostring())
  end

  function _initEngine(ip,key,cb)
    app_key = key
    url =  fmt("https://%s:443",ip)
    DEBUG('info',"HUEv2Engine v%s",version)
    DEBUG('info',"Hub url: %s",url)
    callBack = function() fetchEvents() if cb then cb() end end
    post({type='STARTUP'})
  end

end -- main()

function HUEv2Engine:init(ip,key,cb) setup() main() _initEngine(ip,key,cb) end
