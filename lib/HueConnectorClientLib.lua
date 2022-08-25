--------------------- Hue client lib ----------------------
local VAR = 'HUERSRC_SUB'
local eventCache = {}
local getHueInfo
QuickApp.hue = {}
function QuickApp:setupUpHue(devices)
  self.hue.getRsrc = getHueInfo
  self.hue.idMap={}
  self.hue.deviceMap={}

  function self.hue.listSubscribedDevices()
    assert(quickApp.hue.id,"HueConnector not initiated")
    print("----- Subscriptions ------")
    local subs = self:getVariable(VAR)
    subs = type(subs)=='table' and subs or {}
    for _,uid in ipairs(subs) do
      local r = getHueInfo(uid)
      if r then
        print("Name:",r.name)
        print("  props:",json.encode(r.props))
        print("  methods:",json.encode(r.methods))
      end
    end
    print("--------------------------") 
  end

  local allProps,fmt = { "type","name","model","room","zone","ref" },string.format
  function self.hue.listAllDevices()
    assert(quickApp.hue.id,"HueConnector not initiated")
    print("------ All devices -------")
    local map = self.hue.getRsrc("deviceMap")
    local r={}
    for uid,r0 in pairs(map or {}) do r[#r+1]={uid,r0.type,r0} end
    table.sort(r,function(a,b) return a[2]< b[2] or (a[2]==b[2] and a[1] < b[1]) end)
    for _,i in ipairs(r) do
      local b,k,v = {},i[1],i[3]
      for _,p in ipairs(allProps) do
        if v[p]~=nil then b[#b+1]=fmt("%s='%s', ",p,tostring(v[p])) end
      end
      print("['"..k.."']","= {",table.concat(b),"},")
    end
    print("--------------------------") 
  end

  local function isHueID(id) 
    local hueId = self.hue.idMap[id]
    return hueId or type(id)~="number" and id 
  end

  local oldCall,oldGet = fibaro.call,fibaro.get
  function fibaro.call(id,action,...)
    if type(id) == "table" then
      for _, id2 in pairs(deviceId) do fibaro.call(id2, actionName, ...) end 
      return
    end
    local hueId = isHueID(id)
    if hueId then
      assert(quickApp.hue.id,"HueConnector not initiated")
      return fibaro.call(quickApp.hue.id,"hueCmd",{id=hueId,cmd=action,args={...}})
    else return oldCall(id,action,...) end
  end
  function fibaro.get(id,prop)
    local hueId = isHueID(id)
    if hueId then
      assert(quickApp.hue.id,"HueConnector not initiated")
      if eventCache[hueId] == nil then eventCache[hueId] = getHueInfo(hueId) or {} end
      local v = eventCache[hueId][prop] or {}
      return v.value,v.timestamp
    else return oldGet(id,prop) end
  end

  function self.hue.subscribeTo(devices)
    self:setVariable(VAR,devices)
  end

  if devices then self.hue.subscribeTo(devices) 
  else self.hue.subscribeTo({}) end -- Let HueConnector know that we are an subscriber

end

local function setupDefaultMapping(self)
  local map = self.hue.getRsrc("deviceMap") -- Setup mapping from room+name to Hue ID.
  for id,info in pairs(map or {}) do
    local name = ((info.room and (info.room.."_") or "")..info.name):gsub("[%-%s]","_")
    self.hue.idMap[name]=id
  end
  self.hue.deviceMap = map or {}
end

function QuickApp:HUE_EVENT(uid,ev)
  if uid=="INFO" then -- INFO event when we get contact with HueConnector
    local start = self.hue.id==nil
    self.hue.id=ev.id
    self:debug("HueConnector id:",self.hue.id)

    setupDefaultMapping(self)

    if start and self.hueInited then self:hueInited() end
  else
    local evs = eventCache[uid] or {}
    for k,v in pairs(ev) do evs[k]=v end
    eventCache[uid] = evs
    if self.hueEvent then self:hueEvent(uid,ev) end
  end
end

local rsrcKeys = {}
function getHueInfo(uid)
  assert(quickApp.hue.id,"HueConnector not initiated")
  local key = rsrcKeys[uid]
  if not key then key = "r"..uid:gsub("-","") rsrcKeys[uid]=key end 
  local stat = {api.get("/plugins/"..quickApp.hue.id.."/variables/"..key)}
  return stat[2] == 200 and stat[1].value or nil
end