_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
}

--%%name="HueTest"
--%%quickVars = {["Hue_IP"]=EM.cfg.Hue_IP,["Hue_user"]=EM.cfg.Hue_user }

local v2 = "1948086000"
local fmt = string.format
local debug = { info = true, call=true, event=true, v2api=true, logger=false }
local function DEBUG(tag,str,...) if debug[tag] then quickApp:debug(fmt(str,...)) end end
local function ERROR(str,...) quickApp:error(fmt(str,...)) end
local function WARNING(str,...) quickApp:warning(fmt(str,...)) end

local function createLightManager(bridge) end
local function createGroupedLightManager(bridge) end
local function createRoomManager(bridge) end
local function createZoneManager(bridge) end
local function createSceneManager(bridge) end
local function createActionManager(bridge) end
local function createEventManager(bridge) end

local function createBridge(ip,key,cont)
  self = {}
  self.ip = ip
  self.key = key
  local url =  fmt("https://%s:443",ip)

  local function hueGET(api,res) 
    net.HTTPClient():request(url..api,{
        options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = key }},
        success = function(r) if res then res(true,json.decode(r.data)) end end,
        error = function(e) if res then res(false,e) end end,
      })
  end

  local function checkVersion(cont)
    hueGET("/api/config",function(succ,res)
        if not succ then cont(false,"No connection") end
        if res.swversion >= v2 then
          DEBUG('info',"V2 api available (%s)",res.swversion)
          cont()
        else
          cont(false,WARNING("V2 api not available (%s)",res.swversion))
        end
      end)
  end

  local function getResources(cont)
    cont()
  end

  local function fetchEvents()
    local getw
    local eurl = url.."/eventstream/clip/v2"
    local args = { options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = key }}}
    function args.success(res)
      local data = json.decode(res.data)
      for _,e1 in ipairs(data) do
        if e1.type=='update' then
          for _,e2 in ipairs(e1.data) do
            local d = Resources[e2.id]
            if d.event then 
              DEBUG('event',"Event id:%s type:%s",d.shortId,Resources[e2.id].rType)--,json.encode(e2))
              d:event(e2)
            else
              local _ = 0
              if debug.unknownType then WARNING("Unknow resource type: %s",json.encode(e1)) end
            end
          end
        else
          DEBUG('v2api',"New v2 event type: %s",e1.type)
          DEBUG('v2api',"%s",json.encode(e1))
        end
      end
      getw()
    end
    function args.error(err) if err~="timeout" then ERROR("/eventstream: %s",err) end getw() end
    function getw() net.HTTPClient():request(eurl,args) end
    setTimeout(getw,0)
  end

  checkVersion(function()
      self.lights = createLightManager(self)
      self.groupedLights = createGroupedLightManager(self)
      self.rooms = createRoomManager(self)
      self.zones = createZoneManager(self)
      self.scenes = createSceneManager(self)
      self.actions = createActionManager(self)
      self.event = createEventManager(self)
      getResources(function()
          fetchEvents()
          cont()
        end)
    end
  )
  return self
end

function QuickApp:onInit()
  self:debug(self.name, self.id)
  local ip = self:getVariable("Hue_IP")
  local key = self:getVariable("Hue_user")
  local b = createBridge(ip,key,function(succ,msg) print(msg or "OK") end)
end
