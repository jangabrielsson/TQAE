-- luacheck: globals ignore QuickAppBase QuickApp QuickerAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDeviceQA MotionSensorQA TempSensorQA LuxSensorQA SwitchQA HueTable
-- luacheck: globals ignore LightOnOff LightDimmable LightTemperature LightColor

local function main()

  fibaro.debugFlags.extendedErrors = true
  fibaro.debugFlags.hue = true

  local fmt = string.format
  local url,app_key
  local E = fibaro.event
  local P = fibaro.post
  local v2 = "1948086000"
  local Resources = {}
  local ResourcesType = {}
  local ResourceMap = {}
  local QAs = {}

  local HueDeviceTypes = {
    ["Hue motion sensor"]      = {types={"SML001"},          maker="MotionMaker"},
    ["Hue color lamp"]         = {types={"LCA001","LCT015"}, maker="LightMaker"},
    ["Hue ambiance lamp"]      = {types={"LTA001"},          maker="LightMaker"},
    ["Hue white lamp"]         = {types={"LWA001"},          maker="LightMaker"},
    ["Hue color candle"]       = {types={"LCT012"},          maker="LightMaker"},
    ["Hue filament bulb"]      = {types={"LWO003"},          maker="LightMaker"},
    ["Hue dimmer switch"]      = {types={"RWL021"},          maker="SwitchMaker"},
    ["Hue wall switch module"] = {types={"RDM001"},          maker="SwitchMaker"},
    ["Hue smart plug"]         = {types={"LOM007"},          maker="PlugMaker"},
    ["Hue color spot"]         = {types={"LCG0012"},         maker="LightMaker"},
    ["Philips hue"]            = {types={"LCG0012"},         maker="NopMaker"},
  }

  local function DEBUG(fm,...) print(fmt(fm,...)) end
  local function dumpQAs()
    for id,qa in pairs(QAs) do quickApp:debugf("DeviceId:%s (%s) '%s' %s",qa.id,qa.uid,qa.name,qa.type) end
  end

  local function getServices(t,s)
    local res = {}
    for _,r in ipairs(s) do if r.rtype==t then res[r.rid]=true end end
    return res 
  end

  local function notifier(m,d) 
    local self = { devices = {} }
    function self:update(data) for _,d in ipairs(self.devices) do d[m](d,data) end end
    function self:add(d) self.devices[#self.devices+1]=d end
    return self
  end

  local function hueCall(path,data,op) 
    --DEBUG("P:%s %s",path,json.encode(data))
    net.HTTPClient():request(url..path,{
        options = { method=op or 'PUT', data=data and json.encode(data), checkCertificate=false, headers={ ['hue-application-key'] = app_key }},
        success = function(res)  end,
        error = function(err) quickApp:errorf("hue call, %s %s - %s",path,json.encode(data),err) end,
      })
  end

  class 'HueDeviceQA'(QuickerAppChild)
  function HueDeviceQA:__init(info)
    ResourceMap[info.uid]=self
    if info.name then
      self.name = info.name
      self.name = info.hueType.." "..info.name
    end
    local interfaces = info.interfaces or {}
    if info.bat then interfaces[#interfaces+1]='battery' end
    local args =    {
      name = self.name,
      uid  = info.uid,
      type = info.type,
      quickVars = info.quickVars,
      properties = info.properties,
      interfaces = interfaces,
    }

    QuickerAppChild.__init(self,args)

    QAs[self.id] = self
    self.hueID = info.uid

    if info.bat then 
      ResourceMap[info.bat] = ResourceMap[info.bat] or notifier('battery') 
      ResourceMap[info.bat]:add(self)
      self:battery(Resources[info.bat])
    end
    if info.con then 
      ResourceMap[info.con] = ResourceMap[info.con] or notifier('connectivity') 
      ResourceMap[info.con]:add(self) 
      self:connectivity(Resources[info.con])
    end
  end

  function HueDeviceQA:__tostring()
    return fmt("QA:%s - %s",self.id,self.name)
  end

  function HueDeviceQA:update(ev)
    self:event(ev)
  end

  function HueDeviceQA:hueCall(data)
    hueCall(self.url,data)
  end

  function HueDeviceQA:oldHueCall(data) hueCall(self.orgUrl,data) end

  function HueDeviceQA:event(ev)
    quickApp:debugf("%s %s %s",self.name,self.id,ev)
  end

  function HueDeviceQA:battery(ev)
    self:updateProperty("batteryLevel",ev.power_state.battery_level)
    quickApp:debugf("Battery %s %s %s",self.name,self.id,ev.power_state.battery_level)
  end

  function HueDeviceQA:connectivity(ev)
    self:updateProperty("dead",ev.status ~= 'connected')
    quickApp:debugf("Connectivity %s %s %s",self.name,self.id,ev.status)
  end

  class 'MotionSensorQA'(HueDeviceQA)
  function MotionSensorQA:__init(info)
    info.hueType='Motion'
    info.type="com.fibaro.motionSensor"
    HueDeviceQA.__init(self,info)
    local d = Resources[info.uid]
    self:event(d)
  end
  function MotionSensorQA:event(ev)
    self.value = ev.motion.motion
    self:updateProperty('value',self.value)
    quickApp:debugf("Motion %s %s %s",self.id,self.name,ev.motion.motion)
  end

  class 'TempSensorQA'(HueDeviceQA)
  function TempSensorQA:__init(info)
    info.hueType='Temp'
    info.type="com.fibaro.temperatureSensor"
    HueDeviceQA.__init(self,info)
    local d = Resources[info.uid]
    self:event(d)
  end
  function TempSensorQA:event(ev)
    self.value = ev.temperature.temperature
    self:updateProperty('value',self.value)
    quickApp:debugf("Temp %s %s %s",self.id,self.name,ev.temperature.temperature)
  end

  class 'LuxSensorQA'(HueDeviceQA)
  function LuxSensorQA:__init(info)
    info.hueType='Lux'
    info.type='com.fibaro.lightSensor'
    HueDeviceQA.__init(self,info)
    local d = Resources[info.uid]
    self:event(d)
  end
  function LuxSensorQA:event(ev)
    self.value = math.floor(0.5+math.pow(10, (ev.light.light_level - 1) / 10000))
    self:updateProperty('value',self.value)
    quickApp:debugf("Lux %s %s %s",self.id,self.name,self.value)
  end

  class 'SwitchQA'(HueDeviceQA)
  function SwitchQA:__init(info)
    info.hueType="Switch"
    info.type='com.fibaro.remoteController'
    local buttons = info.quickVars and  info.quickVars['buttons']
    if buttons then
      local css = {}
      for _,id in pairs(buttons) do
        css[#css+1]={ keyAttributes = {"Pressed","Released","HeldDown","Pressed2","Pressed3"},keyId = id }
      end
      info.properties = info.properties or {}
      info.properties.centralSceneSupport = css
    end
    info.interfaces = info.interfaces or {}
    info.interfaces[#info.interfaces+1]='zwaveCentralScene'
    HueDeviceQA.__init(self,info)
    self.buttons = self:getVariable("buttons")
    for id,_ in pairs(self.buttons) do ResourceMap[id]=self end
  end
  function SwitchQA:event(ev)
    quickApp:debugf("Button %s %s %s %s",self.id,self.name,self.buttons[ev.id],ev.button.last_event)
    local fevents = { ['initial_press']='Pressed',['repeat']='HeldDown',['short_release']='Released',['long_release']='Released' }
    local data = {
      type =  "centralSceneEvent",
      source = self.id,
      data = { keyAttribute = fevents[ev.button.last_event], keyId = self.buttons[ev.id] }
    }
    local a,b = api.post("/plugins/publishEvent", data)
  end

  local function onHandler(light,on)
    light:updateProperty('state',on.on)
    light.on = on.on
    DEBUG("Event on(%s) H:%s",light.id,light.on)
    light:updateProperty('value',on.on and (light.fib_bri or 99) or 0)
  end

  local function dimHandler(light,dim)
    light.raw_bri = dim.brightness
    local bri = math.floor(light.raw_bri + 0.5)
    light.fib_bri = math.max(light.cfg.min_dim or 1,bri)
    DEBUG("Event dim(%s) H:%s F:%s (%s)",light.id,light.raw_bri,light.fib_bri,light.on)
    light:updateProperty('value',light.on and light.fib_bri or 0) 
  end

  local function tempHandler(light,temp)
    if not temp.mirek_valid then return end
    light.temp = temp.mirek
    local tempP = math.floor(254*(light.temp-light.cfg.min_mirek)/(light.cfg.max_mirek-light.cfg.min_mirek))
    DEBUG("Event mirek(%s) H:%s F:%s",light.id,temp.mirek,tempP)
    light:updateView('temperature',"value",tostring(tempP))
  end

  local function colorHandler(light,color)
    if not color.xy then return end
    local rgb = fibaro.colorConverter.xyBri2rgb(color.xy.x,color.xy.y,self.raw_bri)
  end

  local lightActions =
  {{'on',onHandler},{'dimming',dimHandler},{'color_temperature',tempHandler},{'color',colorHandler}}

  local function decorateLight(light)
    light.cfg = {}
    light.url="/clip/v2/resource/light/"..light.uid
    function light:turnOn() hueCall(self.url,{on={on=true}}) end
    function light:turnOff() hueCall(self.url,{on={on=false}}) end
    function light:setValue(v) -- 0-99
      DEBUG("setValue(%s) F:%s",light.id,v)
      if v > 100 then v = 100 end
      if v == 0 then
        light:turnOff()
      else
        v = v < self.cfg.min_dim and self.cfg.min_dim or v
        if not light.on then light.fib_bri=v light:turnOn() end
        DEBUG("setValue(%s) H:%s",light.id,v)
        hueCall(self.url,{dimming={brightness=v}})
      end
    end
    function light:temperature(t) -- 0-99
      t = t.values[1]
      DEBUG("setTemp(%s) H:%s",light.id,t)
      t = (t/254) * (light.cfg.max_mirek-light.cfg.min_mirek) + light.cfg.min_mirek
      hueCall(self.url,{color_temperature={mirek=math.floor(t)}})  -- mirek
    end
    
    function light:startLevelIncrease()
      DEBUG("startLevelIncrease")
      self.dimDir = 'UP'
      if self.ref then self.ref=clearTimeout(self.ref) end
      local dimValue = self.raw_bri
      if not self.on then
        self:turnOn()
        dimValue = 0
      end
      local tDelta = (100/(DIMTIME or 10))*(INTERVS or 0.5)
      local function loop()
        self.ref=nil
        dimValue = math.min(dimValue+tDelta,100)
        self:setValue(dimValue)
        if dimValue < 100 then self.ref=setTimeout(loop,1000*(INTERVS or 0.5)) end
      end
      self.ref = setTimeout(loop,0)
    end
    function light:startLevelDecrease()
      DEBUG("startLevelDecrease")
      if not self.on then return end
      if self.ref then self.ref=clearTimeout(self.ref) end
      self.dimDir = 'DOWN'
      local dimValue = self.raw_bri
      local tDelta = (100/(DIMTIME or 10))*(INTERVS or 0.5)
      local function loop()
        self.ref=nil
        dimValue = math.max(dimValue-tDelta,0)
        self:setValue(dimValue)
        if dimValue > 0 then self.ref=setTimeout(loop,1000*(INTERVS or 0.5)) end
      end
      self.ref = setTimeout(loop,0)
    end
    function light:stopLevelChange()
      DEBUG("stopLevelChange")
      if self.ref then self.ref = clearTimeout(self.ref) end
    end
    
    function light:event(ev)
      for _,f in ipairs(lightActions) do
        if ev[f[1]] then 
          --DEBUG("EV(%s) %s",self.id,json.encode(ev[f[1]]))
          f[2](light,ev[f[1]]) 
        end
      end
    end
    local d = Resources[light.uid]
    if d.color_temperature then
      light.cfg.min_mirek = d.color_temperature.mirek_schema.mirek_minimum
      light.cfg.max_mirek = d.color_temperature.mirek_schema.mirek_maximum 
    end
    if d.dimming then light.cfg.min_dim = d.dimming.min_dim_level or 1 end
    local u = url:match("https://(.-):")
    light.orgUrl = "/api/"..app_key..d.id_v1.."/state"
    light:event(d)
  end

  class 'LightOnOff'(HueDeviceQA)
  function LightOnOff:__init(info)
    info.type='com.fibaro.binarySwitch'
    info.properties={}
    info.interfaces = {"light"}
    HueDeviceQA.__init(self,info)
    decorateLight(self)
  end

  class 'LightDimmable'(HueDeviceQA)
  function LightDimmable:__init(info)
    info.type='com.fibaro.multilevelSwitch'
    info.properties={}
    info.interfaces = {"light","levelChange"}
    HueDeviceQA.__init(self,info)
    decorateLight(self)
  end

  local UI3 = {
    {label='Ltemperature',text='Temperature'},
    {slider='temperature',onChanged='temperature'},
  }
  fibaro.UI.transformUI(UI3)
  local v3 = fibaro.UI.mkViewLayout(UI3)
  local cb3 = fibaro.UI.uiStruct2uiCallbacks(UI3)

  class 'LightTemperature'(HueDeviceQA)
  function LightTemperature:__init(info)
    info.type='com.fibaro.multilevelSwitch'
    info.properties={ viewLayout=v3, uiCallbacks=cb3 }
    info.interfaces = {'light','levelChange','quickApp'}
    HueDeviceQA.__init(self,info)
    decorateLight(self)
  end

  local UI4 = {
    {label='Lsaturation',text='Saturation'},
    {slider='saturation',onChanged='saturation'},
    {label='Ltemperature',text='Temperature'},
    {slider='temperature',onChanged='temperature'},
  }
  fibaro.UI.transformUI(UI4)
  local v4 = fibaro.UI.mkViewLayout(UI4)
  local cb4 = fibaro.UI.uiStruct2uiCallbacks(UI4)

  class 'LightColor'(HueDeviceQA)
  function LightColor:__init(info)
    info.type='com.fibaro.colorController'
    info.properties={ viewLayout=v4, uiCallbacks=cb4 }
    info.interfaces = {'light','levelChange','quickApp'}
    HueDeviceQA.__init(self,info)
    decorateLight(self)
  end

  local DeviceMakers = {}
  local ID = 0
  local function nextID() ID=ID+1; return ID end

  local function getDeviceInfo(d)
    local bat = next(getServices("device_power",d.services or {}))
    local con = next(getServices("zigbee_connectivity",d.services or {}))
    local name = d.metadata and d.metadata.name or fmt("Device_%03d",nextID())
    return {bat=bat, con=con, name=name}
  end

  local function copyAndAdd(t,a)
    local res = {} for k,v in pairs(t) do res[k]=v end
    for k,v in pairs(a) do res[k]=v end
    return res
  end

  function DeviceMakers.MotionMaker(d)
    local motionID = next(getServices("motion",d.services))
    local temperatureID = next(getServices("temperature",d.services))
    local light_levelID = next(getServices("light_level",d.services))
    local info = getDeviceInfo(d)
    MotionSensorQA(copyAndAdd(info,{uid=motionID}))
    TempSensorQA(copyAndAdd(info,{uid=temperatureID}))
    LuxSensorQA(copyAndAdd(info,{uid=light_levelID}))
  end

  local lightMap = {
    [1]=LightOnOff,[3]=LightDimmable,[7]=LightTemperature,[15]=LightColor
  }
  function DeviceMakers.LightMaker(d)
    local n = 0
    local light = next(getServices("light",d.services))
    local info = getDeviceInfo(d) info.type='Light'
    light = Resources[light]
    n = n + (light.on and 1 or 0)
    n = n + (light.dimming and 2 or 0)
    n = n + (light.color_temperature and 4 or 0)
    n = n + (light.color and 8 or 0)
    local cl = lightMap[n]
    if not cl then quickApp:warning("Unsupported light:%s %s",d.metadata.name,d.id) return end
    info.uid=info.uid or light.id
    info.hueType="Light"
    cl(info)
  end

  function DeviceMakers.SwitchMaker(d)
    local buttonsIDs = getServices("button",d.services)
    local info = getDeviceInfo(d)
    local buttons = {}
    for id,_ in pairs(buttonsIDs) do
      buttons[id]=Resources[id].metadata.control_id
    end
    info.quickVars={buttons=buttons}
    info.uid=d.id
    SwitchQA(info) 
  end

  function DeviceMakers.PlugMaker(d)
    DeviceMakers.LightMaker(d)
  end

  function DeviceMakers.NopMaker(_) end

  local function makeDevice(d)
    local p = d.product_data
    if HueDeviceTypes[p.product_name] then 
      DeviceMakers[HueDeviceTypes[p.product_name].maker](d)
    else
      quickApp:warningf("Unknown Hue type, %s %s",p.product_name,d.metadata and d.metadata.name or "")
    end
  end

  local function makeGroup(d,t)
    local light = next(getServices("grouped_light",d.services))
    local info = getDeviceInfo(d) info.hueType=t
    info.uid=light
    LightOnOff(info)
  end

  local function call(api,event) 
    net.HTTPClient():request(url..api,{
        options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = app_key }},
        success = function(res) P({type=event,success=json.decode(res.data)}) end,
        error = function(err) P({type=event,error=err})  end,
      })
  end

  E({type='START'},function() call("/api/config",'HUB_VERSION') end)

  E({type='HUB_VERSION',success='$res'},function(env)
      if env.p.res.swversion >= v2 then
        quickApp:debugf("V2 api available (%s)",env.p.res.swversion)
      end
      call("/clip/v2/resource",'REFRESH_RESOURCE')
    end)

  E({type='HUB_VERSION',error='$err'},function(env)
      quickApp:errorf("Connections error from Hub: %s",env.p.err)
    end)

  local function dumpHueTable(rsrc)
    local res,r={"\n"},{}
    local function out(fm,...) res[#res+1]=fmt(fm,...) end
    for id,d in pairs(rsrc.device) do r[#r+1]={id=id,d=d} end
    for id,d in pairs(rsrc.room) do r[#r+1]={id=id,d=d} end
    for id,d in pairs(rsrc.zone or {}) do r[#r+1]={id=id,d=d} end
    table.sort(r,function(a,b) return a.id < b.id end)
    out("HueTable = {\n")
    for _,e in ipairs(r) do
      local pt = e.d.product_data and e.d.product_data.product_name or "*"
      local function w(s) return "'"..s.."'" end
      out("  ['%s'] = { type=%-10s, product=%-25s, name = %s },\n",e.id,w(e.d.type),w(pt),w(e.d.metadata.name))
    end
    out("}")
    print(table.concat(res))
  end

  E({type='REFRESH_RESOURCE',success='$res'},function(env)
      for _,d in ipairs(env.p.res.data or {}) do
        --quickApp:debugf("%s %s %s",d.type,d.metadata and d.metadata.name,d.id)
        Resources[d.id]=d
        ResourcesType[d.type] = ResourcesType[d.type] or {}
        ResourcesType[d.type][d.id]=d
      end
      local hueDevices = HueTable or {}
      for _,d in pairs(ResourcesType.device or {}) do 
        if hueDevices[d.id] then makeDevice(d) end 
      end
      for _,d in pairs(ResourcesType.room or {}) do 
        if hueDevices[d.id] then makeGroup(d,"Room") end 
      end
      for _,d in pairs(ResourcesType.zone or {}) do 
        if hueDevices[d.id] then makeGroup(d,"Zone") end 
      end
      dumpQAs()
      dumpHueTable(ResourcesType)
    end)

  E({type='GET_DEVICES',error='$err'},function(env) quickApp:error(env.p.err) end)

  local function fetchEvents()
    local getw
    local eurl = url.."/eventstream/clip/v2"
    local args = { options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = app_key }}}
    function args.success(res)
      local data = json.decode(res.data)
      for _,e in ipairs(data) do
        if e.type=='update' then
          for _,e in ipairs(e.data) do
            if ResourceMap[e.id] then 
              ResourceMap[e.id]:update(e)
            else
              --quickApp:warningf("Unknow resource type:%s",e)
            end
          end
        else
          quickApp:debugf("New event type:%s",e.type)
          quickApp:debugf("%s",json.encode(e))
        end
      end
      getw()
    end
    function args.error(err) if err~="timeout" then quickApp:errorf("/eventstream: %s",err) end getw() end
    function getw() net.HTTPClient():request(eurl,args) end
    setTimeout(getw,0)
  end

  url = quickApp:getVariable("Hue_IP")
  app_key = quickApp:getVariable("Hue_User")
  url = fmt("https://%s:443",url)
  quickApp:post({type='START'})
  fetchEvents()
end
function QuickApp:onInit()
  setTimeout(main,0)
end
